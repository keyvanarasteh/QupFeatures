import DesignSystem
import FeatureContracts
import Networking
import SwiftUI

public struct AIAgentsListView: View {
    @Environment(\.cupertinoColors) private var colors
    @StateObject private var store: AIAgentsStore
    @State private var editingAccount: AgentAccount?
    @State private var isAddingAccount = false
    @State private var pendingDelete: AgentAccount?
    @State private var showCheatsheet = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    public init(settings: FeatureSettingsClient, apiClient: APIClient) {
        _store = StateObject(wrappedValue: AIAgentsStore(settings: settings, api: AIAgentCredentialsAPI(client: apiClient)))
    }

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "AI Agents",
                    subtitle: "Track usage limits across your Claude, Codex, Gemini, Grok, and Kimi accounts",
                    systemImage: "cpu"
                )

                if !store.isLoading {
                    if !store.accounts.isEmpty { summaryCard }
                    if !store.notificationsAuthorized { notificationsCard }
                }

                if store.isLoading {
                    ProgressView("Loading accounts…")
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.xxxl)
                } else if store.accounts.isEmpty {
                    EmptyStateView(
                        title: "No Accounts Yet",
                        message: "Add a Claude, Codex, Gemini, Grok, or Kimi account to start tracking its usage limits.",
                        systemImage: "cpu",
                        actionTitle: "Add Account"
                    ) { isAddingAccount = true }
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(store.accountsSortedByUrgency) { account in
                            AgentAccountCard(
                                account: account,
                                isCheckingUsage: store.checkingAccountIDs.contains(account.id),
                                isCLIInstalled: store.cliInstalledAccountIDs.contains(account.id),
                                isSettingUpCLI: store.settingUpCLIAccountIDs.contains(account.id),
                                onCheckUsage: { Task { await store.checkUsage(for: account) } },
                                onSetUpCLI: { Task { await store.setUpCLI(for: account) } },
                                onEdit: { editingAccount = account },
                                onDelete: { pendingDelete = account },
                                onShowCheatsheet: { showCheatsheet = true }
                            )
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("AI Agents")
        .toolbar {
            ToolbarItem {
                Button("Add Account", systemImage: "plus") { isAddingAccount = true }
            }
        }
        .task {
            await store.load()
            #if os(macOS)
            await store.performAutomaticUsageCheckups()
            #endif
        }
        .alert("Usage Checkup", isPresented: .init(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "Unknown error")
        }
        .sheet(isPresented: $isAddingAccount) {
            AgentAccountEditorSheet(account: nil) { account in await store.save(account) }
        }
        .sheet(item: $editingAccount) { account in
            AgentAccountEditorSheet(account: account) { updated in await store.save(updated) }
        }
        .sheet(isPresented: $showCheatsheet) {
            ClaudeCheatsheetModal()
        }
        .alert("Delete Account?", isPresented: .init(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let account = pendingDelete { Task { await store.delete(account) } }
                pendingDelete = nil
            }
        } message: {
            if let account = pendingDelete {
                Text("This removes \(account.nickname) and cancels its scheduled reminders.")
            }
        }
    }

    private var summaryCard: some View {
        CardView {
            HStack(spacing: Theme.Spacing.xl) {
                summaryStat(value: "\(store.accounts.count)", label: store.accounts.count == 1 ? "Account" : "Accounts")
                SoftDivider().frame(height: 32)
                summaryStat(
                    value: "\(store.accountsNearingLimit)",
                    label: "Near Limit",
                    tone: store.accountsNearingLimit > 0 ? .danger : .neutral
                )
                SoftDivider().frame(height: 32)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Next Reset").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    if let soonestReset = store.soonestReset {
                        Text(Self.relativeFormatter.localizedString(for: soonestReset, relativeTo: .now))
                            .font(Theme.Typography.bodyEmphasized)
                            .foregroundStyle(colors.fg)
                    } else {
                        Text("None scheduled").font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.mutedFg)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func summaryStat(value: String, label: String, tone: StatusTone = .neutral) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
            Text(value)
                .font(Theme.Typography.title3)
                .foregroundStyle(tone == .neutral ? colors.fg : tone.color(in: colors))
        }
    }

    private var notificationsCard: some View {
        CardView {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "bell.badge")
                    .font(.title3)
                    .foregroundStyle(colors.primary)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Enable Reminders").font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
                    Text("Get notified when a limit is about to reset or an account is nearing its cap.")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(colors.mutedFg)
                }
                Spacer(minLength: 0)
                CupertinoSecondaryButton("Enable", systemImage: "bell") {
                    Task { await store.requestNotifications() }
                }
            }
        }
    }
}
