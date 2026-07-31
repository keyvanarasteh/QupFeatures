import Combine
import FeatureContracts
import Foundation

@MainActor
public final class AIAgentsStore: ObservableObject {
    private static let accountsKey = "accounts"

    @Published public private(set) var accounts: [AgentAccount] = []
    @Published public private(set) var notificationsAuthorized = false
    @Published public private(set) var isLoading = true
    @Published public private(set) var checkingAccountIDs: Set<UUID> = []
    @Published public private(set) var lastUsageCheckupAt: Date?
    @Published public var lastError: String?
    /// IDs of accounts whose provider has a dedicated Agent CLI Setup target
    /// that's installed and healthy on this Mac (macOS only; always empty on iOS).
    @Published public private(set) var cliInstalledAccountIDs: Set<UUID> = []
    @Published public private(set) var settingUpCLIAccountIDs: Set<UUID> = []

    private let settings: FeatureSettingsClient
    private let notifier: AIAgentsNotifying
    private let usageChecker: any AgentUsageChecking
    private let cliInstallChecker: any AgentCLIInstallChecking
    private let api: AIAgentCredentialsAPI?

    public init(
        settings: FeatureSettingsClient,
        notifier: AIAgentsNotifying = LiveAIAgentsNotifier(),
        api: AIAgentCredentialsAPI? = nil
    ) {
        self.settings = settings
        self.notifier = notifier
        self.usageChecker = LiveAgentUsageChecker()
        self.cliInstallChecker = LiveAgentCLIInstallChecker()
        self.api = api
    }

    init(
        settings: FeatureSettingsClient,
        notifier: AIAgentsNotifying,
        usageChecker: any AgentUsageChecking = LiveAgentUsageChecker(),
        cliInstallChecker: any AgentCLIInstallChecking = LiveAgentCLIInstallChecker(),
        api: AIAgentCredentialsAPI? = nil
    ) {
        self.settings = settings
        self.notifier = notifier
        self.usageChecker = usageChecker
        self.cliInstallChecker = cliInstallChecker
        self.api = api
    }

    /// Soonest upcoming reset first; accounts with no dated limit sink to the bottom.
    public var accountsSortedByUrgency: [AgentAccount] {
        accounts.sorted { lhs, rhs in
            switch (lhs.nextReset, rhs.nextReset) {
            case let (l?, r?): return l < r
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
            }
        }
    }

    public var accountsNearingLimit: Int { accounts.filter(\.hasNearLimitWarning).count }
    public var soonestReset: Date? { accounts.compactMap(\.nextReset).min() }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await settings.value([AgentAccount].self, forKey: Self.accountsKey) ?? []
        } catch {
            lastError = "Couldn't load saved accounts."
        }
        notificationsAuthorized = await notifier.isAuthorized()
        await syncWithServer()
        refreshCLIInstallStatus()
    }

    /// Re-checks, for every account whose provider has a dedicated Agent CLI
    /// Setup target, whether that CLI is installed and healthy on this Mac —
    /// no caching, no persisted flag, so it's always current with whatever
    /// the Setup page last did. Always empty on iOS (`cliInstallChecker`
    /// reports nothing installed there).
    public func refreshCLIInstallStatus() {
        var installed: Set<UUID> = []
        for account in accounts {
            guard let target = account.provider.setupTarget else { continue }
            if cliInstallChecker.isInstalled(target) { installed.insert(account.id) }
        }
        cliInstalledAccountIDs = installed
    }

    /// One-tap install for an account's CLI straight from its card — the
    /// same operation as the Agent CLI Setup page's "Setup" button, scoped
    /// to this account's provider. No-op if the account's provider has no
    /// dedicated CLI.
    public func setUpCLI(for account: AgentAccount) async {
        guard let target = account.provider.setupTarget else { return }
        settingUpCLIAccountIDs.insert(account.id)
        defer { settingUpCLIAccountIDs.remove(account.id) }
        do {
            try cliInstallChecker.install(target)
            refreshCLIInstallStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func requestNotifications() async {
        notificationsAuthorized = await notifier.requestAuthorization()
        for account in accounts { await notifier.reschedule(for: account) }
    }

    public func save(_ account: AgentAccount) async {
        var value = account
        value.updatedAt = .now
        if let index = accounts.firstIndex(where: { $0.id == value.id }) {
            accounts[index] = value
        } else {
            accounts.append(value)
        }
        await persist()
        await notifier.reschedule(for: value)
        await pushToServer(accountID: value.id)
        refreshCLIInstallStatus()
    }

    public func delete(_ account: AgentAccount) async {
        accounts.removeAll { $0.id == account.id }
        await persist()
        await notifier.cancelAll(for: account)
        if let remoteCredentialID = account.remoteCredentialID {
            await deleteFromServer(id: remoteCredentialID)
        }
    }

    public func checkUsage(for account: AgentAccount) async {
        guard [.claude, .codex, .grok].contains(account.provider), !checkingAccountIDs.contains(account.id) else { return }
        checkingAccountIDs.insert(account.id)
        defer { checkingAccountIDs.remove(account.id) }
        do {
            let snapshot = try await usageChecker.checkUsage(for: account.provider)
            guard var current = accounts.first(where: { $0.id == account.id }) else { return }
            current.limits = snapshot.limits
            await save(current)
            lastUsageCheckupAt = snapshot.checkedAt
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The CLI reports only its currently authenticated identity, so automatic
    /// refresh is unambiguous only when exactly one account for a provider is saved.
    public func performAutomaticUsageCheckups() async {
        for provider in [AgentProvider.claude, .codex, .grok] {
            let providerAccounts = accounts.filter { $0.provider == provider }
            guard providerAccounts.count == 1, let account = providerAccounts.first else { continue }
            await checkUsage(for: account)
        }
    }

    private func persist() async {
        do {
            try await settings.setValue(accounts, forKey: Self.accountsKey)
        } catch {
            lastError = "Couldn't save changes."
        }
    }

    // MARK: - Server sync (core-api `provider: "ai-agent"` credentials)
    //
    // The local cache above is always the source of truth for the UI and works
    // fully offline. When `api` is available, `load()` reconciles it against
    // the server afterwards so accounts follow the user across devices;
    // `save()`/`delete()` best-effort push each change right after it lands
    // locally. Any sync failure only sets `lastError` — it never rolls back
    // or blocks the local change.

    /// Pulls the server's `ai-agent` rows, links/updates/creates local
    /// records to match, drops local records whose linked row was deleted
    /// elsewhere, then pushes any still-unsynced local-only records up.
    private func syncWithServer() async {
        guard let api else { return }
        do {
            let remote = try await api.listCredentials()
            var remoteIDsSeen: Set<Int> = []

            for credential in remote {
                remoteIDsSeen.insert(credential.id)
                if let index = accounts.firstIndex(where: { $0.remoteCredentialID == credential.id }) {
                    accounts[index].applyRemote(credential)
                } else if let index = accounts.firstIndex(where: {
                    $0.remoteCredentialID == nil && $0.email == credential.credKey
                }) {
                    accounts[index].remoteCredentialID = credential.id
                    accounts[index].applyRemote(credential)
                } else {
                    accounts.append(AgentAccount(credential: credential))
                }
            }

            accounts.removeAll { account in
                guard let remoteCredentialID = account.remoteCredentialID else { return false }
                return !remoteIDsSeen.contains(remoteCredentialID)
            }
            await persist()

            for account in accounts where account.remoteCredentialID == nil {
                await pushToServer(accountID: account.id)
            }
        } catch {
            lastError = "Couldn't sync accounts with the server."
        }
    }

    private func pushToServer(accountID: UUID) async {
        guard let api, let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        do {
            let id = try await api.saveCredential(accounts[index].credentialWrite())
            accounts[index].remoteCredentialID = id
            await persist()
        } catch {
            lastError = "Saved locally, but couldn't sync to the server."
        }
    }

    private func deleteFromServer(id: Int) async {
        guard let api else { return }
        do {
            try await api.deleteCredential(id: id)
        } catch {
            lastError = "Deleted locally, but couldn't remove it from the server."
        }
    }
}
