import Foundation

/// Bridges `AIAgentsStore` to the Agent CLI Setup engine so a tracked
/// account's card can show whether its provider's CLI is installed on this
/// Mac, and offer a one-tap install. A protocol (rather than calling
/// `AgentSetupEngine` directly) keeps `AIAgentsStore` testable without
/// touching the real machine's `~/.local`/`~/.config`, matching how
/// `AgentUsageChecking` isolates the usage-checkup CLI calls.
protocol AgentCLIInstallChecking: Sendable {
    func isInstalled(_ target: AgentSetupTarget) -> Bool
    func install(_ target: AgentSetupTarget) throws
}

struct LiveAgentCLIInstallChecker: AgentCLIInstallChecking {
    func isInstalled(_ target: AgentSetupTarget) -> Bool {
        #if os(macOS)
        AgentSetupEngine.check(target, prefix: AgentSetupEngine.defaultPrefix).isHealthy
        #else
        false
        #endif
    }

    func install(_ target: AgentSetupTarget) throws {
        #if os(macOS)
        try AgentSetupEngine.setup(target, prefix: AgentSetupEngine.defaultPrefix)
        #endif
    }
}
