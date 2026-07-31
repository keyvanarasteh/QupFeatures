import FeatureContracts
import Foundation
import Networking
import Testing
@testable import AIAgentsFeature

@Test @MainActor func stableFeatureIdentifier() {
    #expect(AIAgentsFeatureModule.featureID.rawValue == "tech.qline.aiagents")
}

@Test func agentAccountCodableRoundTrip() throws {
    let account = AgentAccount(
        provider: .claude,
        nickname: "claude3",
        email: "gokcer9261@gmail.com",
        planTier: "Max 20x",
        limits: [UsageLimit(window: .weekly, usedPercent: 42, resetsAt: Date(timeIntervalSinceNow: 3600), label: nil)]
    )
    let data = try JSONEncoder().encode(account)
    let decoded = try JSONDecoder().decode(AgentAccount.self, from: data)
    #expect(decoded == account)
}

@Test func usageLimitSeverityThresholds() {
    #expect(UsageLimit(window: .daily, usedPercent: 0).severity == .success)
    #expect(UsageLimit(window: .daily, usedPercent: 59).severity == .success)
    #expect(UsageLimit(window: .daily, usedPercent: 60).severity == .warning)
    #expect(UsageLimit(window: .daily, usedPercent: 84).severity == .warning)
    #expect(UsageLimit(window: .daily, usedPercent: 85).severity == .danger)
    #expect(UsageLimit(window: .daily, usedPercent: 85).isNearLimit)
    #expect(!UsageLimit(window: .daily, usedPercent: 84).isNearLimit)
}

@Test func usageLimitClampsPercent() {
    #expect(UsageLimit(window: .daily, usedPercent: -10).usedPercent == 0)
    #expect(UsageLimit(window: .daily, usedPercent: 150).usedPercent == 100)
}

@Test func parsesStructuredClaudeUsageJSON() throws {
    let json = #"""
    {
      "type": "result",
      "usage_limits": {
        "five_hour": { "utilization": 37.5, "resets_at": "2026-07-23T12:00:00Z" },
        "seven_day": { "utilization": 82, "resets_at": "2026-07-27T12:00:00Z" },
        "seven_day_sonnet": { "utilization": 24, "resets_at": "2026-07-27T12:00:00Z" }
      }
    }
    """#

    let limits = try AgentUsageResponseParser.parse(Data(json.utf8))
    #expect(limits.count == 3)
    #expect(limits.contains { $0.window == .session && $0.usedPercent == 37.5 })
    #expect(limits.contains { $0.label == "Seven Day Sonnet" && $0.usedPercent == 24 })
}

@Test func parsesCodexJSONLUsageText() throws {
    let jsonl = #"""
    {"type":"thread.started","thread_id":"test"}
    {"type":"item.completed","item":{"type":"agent_message","text":"Weekly: 48% used, resets at 2026-07-27T12:00:00Z"}}
    """#

    let limits = try AgentUsageResponseParser.parse(Data(jsonl.utf8))
    #expect(limits.count == 1)
    #expect(limits.first?.window == .weekly)
    #expect(limits.first?.usedPercent == 48)
    #expect(limits.first?.resetsAt != nil)
}

@Test @MainActor func providerCheckupUpdatesAndPersistsLimits() async {
    let settings = FeatureSettingsClient.inMemory()
    let expected = UsageLimit(window: .weekly, usedPercent: 61)
    let store = AIAgentsStore(
        settings: settings,
        notifier: NoopNotifier(),
        usageChecker: StubAgentUsageChecker(snapshot: .init(limits: [expected], checkedAt: .now))
    )
    let account = AgentAccount(provider: .claude, nickname: "Claude", email: "a@example.com")
    await store.save(account)

    await store.checkUsage(for: account)

    #expect(store.accounts.first?.limits == [expected])
    #expect(store.lastUsageCheckupAt != nil)
    let reloaded = AIAgentsStore(settings: settings, notifier: NoopNotifier())
    await reloaded.load()
    #expect(reloaded.accounts.first?.limits == [expected])
}

@Test @MainActor func storeSortsByUpcomingReset() async {
    let store = AIAgentsStore(settings: .inMemory(), notifier: NoopNotifier())

    let soon = AgentAccount(provider: .grok, nickname: "grok2", email: "a@example.com", limits: [
        UsageLimit(window: .weekly, usedPercent: 30, resetsAt: Date(timeIntervalSinceNow: 3600)),
    ])
    let later = AgentAccount(provider: .codex, nickname: "codex1", email: "b@example.com", limits: [
        UsageLimit(window: .weekly, usedPercent: 30, resetsAt: Date(timeIntervalSinceNow: 7200)),
    ])
    let noReset = AgentAccount(provider: .kimi, nickname: "kimi1", email: "c@example.com", limits: [])

    await store.save(later)
    await store.save(noReset)
    await store.save(soon)

    let ordered = store.accountsSortedByUrgency.map(\.nickname)
    #expect(ordered == ["grok2", "codex1", "kimi1"])
}

@Test func everySetupTargetWithAnAccountProviderMapsBackToItself() {
    for target in AgentSetupTarget.allCases {
        guard let provider = target.accountProvider else { continue }
        #expect(provider.setupTarget == target)
    }
}

@Test func kimiAndOtherProvidersHaveNoSetupTarget() {
    #expect(AgentProvider.kimi.setupTarget == nil)
    #expect(AgentProvider.other.setupTarget == nil)
}

@Test @MainActor func refreshCLIInstallStatusOnlyFlagsAccountsTheCheckerReportsInstalled() async {
    let store = AIAgentsStore(
        settings: .inMemory(),
        notifier: NoopNotifier(),
        cliInstallChecker: StubAgentCLIInstallChecker(installed: [.claude])
    )
    let claude = AgentAccount(provider: .claude, nickname: "claude", email: "a@example.com")
    let kimi = AgentAccount(provider: .kimi, nickname: "kimi", email: "b@example.com")
    await store.save(claude)
    await store.save(kimi)

    store.refreshCLIInstallStatus()

    #expect(store.cliInstalledAccountIDs == [claude.id])
}

@Test @MainActor func setUpCLIInstallsThenRefreshesStatus() async {
    let checker = StubAgentCLIInstallChecker(installed: [])
    let store = AIAgentsStore(settings: .inMemory(), notifier: NoopNotifier(), cliInstallChecker: checker)
    let account = AgentAccount(provider: .grok, nickname: "grok", email: "a@example.com")
    await store.save(account)
    #expect(store.cliInstalledAccountIDs.isEmpty)

    await store.setUpCLI(for: account)

    #expect(checker.installCallCount == 1)
    #expect(store.cliInstalledAccountIDs == [account.id])
}

@Test @MainActor func setUpCLIIsNoOpForProviderWithoutASetupTarget() async {
    let checker = StubAgentCLIInstallChecker(installed: [])
    let store = AIAgentsStore(settings: .inMemory(), notifier: NoopNotifier(), cliInstallChecker: checker)
    let account = AgentAccount(provider: .kimi, nickname: "kimi", email: "a@example.com")
    await store.save(account)

    await store.setUpCLI(for: account)

    #expect(checker.installCallCount == 0)
}

@Test @MainActor func storeDeletesAccount() async {
    let store = AIAgentsStore(settings: .inMemory(), notifier: NoopNotifier())
    let account = AgentAccount(provider: .claude, nickname: "claude3", email: "a@example.com")
    await store.save(account)
    #expect(store.accounts.count == 1)
    await store.delete(account)
    #expect(store.accounts.isEmpty)
}

// MARK: - Server sync (`provider: "ai-agent"` credentials)

@Test func listCredentialsSendsProviderFilter() async throws {
    let session = ScriptedSession([.ok(#"{"credentials":[]}"#)])
    let api = AIAgentCredentialsAPI(client: makeScriptedClient(session: session))
    let credentials = try await api.listCredentials()
    #expect(credentials.isEmpty)

    let request = try #require(await session.lastRequest())
    #expect(request.url?.query?.contains("provider=ai-agent") == true)
}

@Test func saveCredentialOmitsCredSecret() async throws {
    let session = ScriptedSession([.ok(#"{"success":true,"id":42}"#)])
    let api = AIAgentCredentialsAPI(client: makeScriptedClient(session: session))
    let account = AgentAccount(provider: .claude, nickname: "Work", email: "a@example.com", planTier: "Max 20x")
    let id = try await api.saveCredential(account.credentialWrite())
    #expect(id == 42)

    let request = try #require(await session.lastRequest())
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["provider"] as? String == "ai-agent")
    #expect(json["cred_key"] as? String == "a@example.com")
    #expect(json["cred_secret"] == nil)
    let extraData = try #require(json["extra_data"] as? [String: Any])
    #expect(extraData["agent_provider"] as? String == "claude")
    #expect(extraData["plan_tier"] as? String == "Max 20x")
}

@Test @MainActor func loadLinksLocalAccountToMatchingRemoteRow() async throws {
    let json = """
    {"credentials":[{
        "id": 7, "provider": "ai-agent", "label": "Work claude",
        "cred_key": "a@example.com",
        "extra_data": {"agent_provider": "claude", "plan_tier": "Max 20x", "notes": null, "remind_before_reset": true, "alert_near_limit": true},
        "is_default": false, "created_at": "2026-01-01 00:00:00", "updated_at": "2026-01-01 00:00:00"
    }]}
    """
    let session = ScriptedSession([.ok(json)])
    let settings = FeatureSettingsClient.inMemory()
    let store = AIAgentsStore(
        settings: settings,
        notifier: NoopNotifier(),
        api: AIAgentCredentialsAPI(client: makeScriptedClient(session: session))
    )
    await store.save(AgentAccount(provider: .claude, nickname: "claude", email: "a@example.com"))

    await store.load()

    #expect(store.accounts.count == 1)
    #expect(store.accounts.first?.remoteCredentialID == 7)
    #expect(store.accounts.first?.nickname == "Work claude")
    #expect(store.accounts.first?.planTier == "Max 20x")
}

@Test @MainActor func loadPushesUnsyncedLocalAccountToServer() async throws {
    // Seed the local cache the way an offline-created account would exist —
    // via a plain, sync-less store — so the network session below only ever
    // sees the two calls `load()` itself makes.
    let settings = FeatureSettingsClient.inMemory()
    let offlineStore = AIAgentsStore(settings: settings, notifier: NoopNotifier())
    await offlineStore.save(AgentAccount(provider: .codex, nickname: "codex1", email: "b@example.com"))

    let session = ScriptedSession([
        .ok(#"{"credentials":[]}"#),
        .ok(#"{"success":true,"id":99}"#),
    ])
    let store = AIAgentsStore(
        settings: settings,
        notifier: NoopNotifier(),
        api: AIAgentCredentialsAPI(client: makeScriptedClient(session: session))
    )

    await store.load()

    #expect(store.accounts.first?.remoteCredentialID == 99)
}

/// An `HTTPSession` that returns scripted responses in order (repeating the
/// last one) and records every request it receives.
private actor ScriptedSession: HTTPSession {
    struct Stub: Sendable {
        var status: Int
        var data: Data
        init(status: Int, data: Data = Data()) { self.status = status; self.data = data }
        static func ok(_ json: String) -> Stub { Stub(status: 200, data: Data(json.utf8)) }
    }

    private var stubs: [Stub]
    private(set) var recorded: [URLRequest] = []

    init(_ stubs: [Stub]) {
        precondition(!stubs.isEmpty)
        self.stubs = stubs
    }

    func lastRequest() -> URLRequest? { recorded.last }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recorded.append(request)
        let stub = stubs.count > 1 ? stubs.removeFirst() : stubs[0]
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
        return (stub.data, response)
    }
}

private func makeScriptedClient(session: HTTPSession) -> APIClient {
    APIClient(
        baseURL: URL(string: "https://example.test")!,
        session: session,
        retryPolicy: .none,
        encoder: {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        },
        decoder: {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        },
        sleep: { _ in }
    )
}

private extension FeatureSettingsClient {
    static func inMemory() -> FeatureSettingsClient {
        let box = InMemoryBox()
        return FeatureSettingsClient(
            data: { key in await box.get(key) },
            setData: { data, key in await box.set(key, data) },
            remove: { key in await box.remove(key) }
        )
    }
}

private actor InMemoryBox {
    private var storage: [String: Data] = [:]
    func get(_ key: String) -> Data? { storage[key] }
    func set(_ key: String, _ data: Data) { storage[key] = data }
    func remove(_ key: String) { storage.removeValue(forKey: key) }
}

/// Avoids touching `UNUserNotificationCenter`, which crashes when driven from
/// a bare SwiftPM test host (no app bundle).
private struct NoopNotifier: AIAgentsNotifying {
    func isAuthorized() async -> Bool { false }
    func requestAuthorization() async -> Bool { false }
    func reschedule(for account: AgentAccount) async {}
    func cancelAll(for account: AgentAccount) async {}
}

private struct StubAgentUsageChecker: AgentUsageChecking {
    let snapshot: AgentUsageSnapshot
    func checkUsage(for provider: AgentProvider) async throws -> AgentUsageSnapshot { snapshot }
}

/// Every access happens on the test's `@MainActor`, same as the store under
/// test, so mutation is serialized despite the `@unchecked` conformance.
private final class StubAgentCLIInstallChecker: AgentCLIInstallChecking, @unchecked Sendable {
    private var installedTargets: Set<AgentSetupTarget>
    private(set) var installCallCount = 0

    init(installed: Set<AgentSetupTarget>) {
        installedTargets = installed
    }

    func isInstalled(_ target: AgentSetupTarget) -> Bool {
        installedTargets.contains(target)
    }

    func install(_ target: AgentSetupTarget) throws {
        installCallCount += 1
        installedTargets.insert(target)
    }
}
