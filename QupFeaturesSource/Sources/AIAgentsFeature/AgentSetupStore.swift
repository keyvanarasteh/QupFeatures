#if os(macOS)
import AppKit
import Combine
import FeatureContracts
import Foundation

@MainActor
public final class AgentSetupStore: ObservableObject {
    private static let prefixKey = "setupPrefix"

    @Published public private(set) var prefixPath: String
    @Published public private(set) var reports: [AgentSetupTarget: AgentCheckReport] = [:]
    @Published public private(set) var sandboxStatuses: [AgentSetupTarget: AgentSandboxStatus] = [:]
    @Published public private(set) var busyTargets: Set<AgentSetupTarget> = []
    @Published public private(set) var isLoading = true
    @Published public var lastError: String?

    private let settings: FeatureSettingsClient

    public init(settings: FeatureSettingsClient) {
        self.settings = settings
        prefixPath = AgentSetupEngine.defaultPrefix.path
    }

    private var prefixURL: URL { URL(fileURLWithPath: prefixPath, isDirectory: true) }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        if let saved = try? await settings.value(String.self, forKey: Self.prefixKey), !saved.isEmpty {
            prefixPath = saved
        }
        await refreshAll()
    }

    public func updatePrefix(_ path: String) async {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        prefixPath = trimmed.isEmpty ? AgentSetupEngine.defaultPrefix.path : (trimmed as NSString).expandingTildeInPath
        do {
            try await settings.setValue(prefixPath, forKey: Self.prefixKey)
        } catch {
            lastError = "Couldn't save the install location."
        }
        await refreshAll()
    }

    public func resetPrefixToDefault() async {
        await updatePrefix(AgentSetupEngine.defaultPrefix.path)
    }

    // MARK: - Per-target actions

    public func isBusy(_ target: AgentSetupTarget) -> Bool { busyTargets.contains(target) }

    public func check(_ target: AgentSetupTarget) async {
        await run(target) { reports[target] = AgentSetupEngine.check(target, prefix: prefixURL) }
    }

    public func verify(_ target: AgentSetupTarget) async {
        await run(target) { reports[target] = AgentSetupEngine.verify(target, prefix: prefixURL) }
    }

    public func setup(_ target: AgentSetupTarget) async {
        await run(target) {
            try AgentSetupEngine.setup(target, prefix: prefixURL)
            reports[target] = AgentSetupEngine.verify(target, prefix: prefixURL)
        }
    }

    /// The non-dry-run half of `fresh-cli.sh` for one target — removes the
    /// wrapper, alias, config, and data directory. Callers should confirm
    /// with the user first; `resetPreview(for:)` supplies what would go.
    public func reset(_ target: AgentSetupTarget) async {
        await run(target) {
            try AgentSetupEngine.reset([target], prefix: prefixURL)
            reports[target] = AgentSetupEngine.check(target, prefix: prefixURL)
        }
    }

    public func resetPreview(for target: AgentSetupTarget) -> [AgentResetItem] {
        AgentSetupEngine.resetItems(for: [target], prefix: prefixURL)
    }

    public func refreshSandboxStatus(_ target: AgentSetupTarget) {
        sandboxStatuses[target] = AgentSetupEngine.sandboxStatus(target, prefix: prefixURL)
    }

    public func installSandbox(_ target: AgentSetupTarget) async {
        await run(target) {
            try AgentSetupEngine.sandboxInstall(target, prefix: prefixURL)
            sandboxStatuses[target] = AgentSetupEngine.sandboxStatus(target, prefix: prefixURL)
        }
    }

    public func uninstallSandbox(_ target: AgentSetupTarget) async {
        await run(target) {
            try AgentSetupEngine.sandboxUninstall(target, prefix: prefixURL)
            sandboxStatuses[target] = AgentSetupEngine.sandboxStatus(target, prefix: prefixURL)
        }
    }

    /// The interactive counterpart of `download.sh`'s primary artifact:
    /// opens the provider's homepage instead of copying a marketing page.
    public func openHomepage(_ target: AgentSetupTarget) {
        NSWorkspace.shared.open(target.homepage)
    }

    // MARK: - Bulk actions (`setup-agents.sh all check` / `all verify`)

    public func checkAll() async {
        for target in AgentSetupTarget.allCases { await check(target) }
    }

    public func verifyAll() async {
        for target in AgentSetupTarget.allCases { await verify(target) }
    }

    private func refreshAll() async {
        for target in AgentSetupTarget.allCases {
            reports[target] = AgentSetupEngine.check(target, prefix: prefixURL)
            sandboxStatuses[target] = AgentSetupEngine.sandboxStatus(target, prefix: prefixURL)
        }
    }

    private func run(_ target: AgentSetupTarget, _ body: () throws -> Void) async {
        busyTargets.insert(target)
        defer { busyTargets.remove(target) }
        do {
            try body()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
#endif
