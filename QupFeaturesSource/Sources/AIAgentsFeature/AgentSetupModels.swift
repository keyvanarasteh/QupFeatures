import Foundation

/// One row of a `check` (`check-cli.sh`) or `verify` (`verify-cli.sh`) report.
public struct AgentCheckItem: Identifiable, Sendable, Equatable {
    public enum Status: String, Sendable { case pass, fail }

    public var id: String
    public var title: String
    public var status: Status
    public var detail: String

    public init(id: String, title: String, status: Status, detail: String) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
    }
}

/// The full set of check rows for one target, plus the pass/fail tally shown
/// by `check-cli.sh`/`verify-cli.sh` ("N pass, N fail").
public struct AgentCheckReport: Sendable, Equatable {
    public var items: [AgentCheckItem]
    public var checkedAt: Date

    public init(items: [AgentCheckItem], checkedAt: Date = .now) {
        self.items = items
        self.checkedAt = checkedAt
    }

    public var passCount: Int { items.count(where: { $0.status == .pass }) }
    public var failCount: Int { items.count(where: { $0.status == .fail }) }
    public var isHealthy: Bool { !items.isEmpty && failCount == 0 }
}

/// One filesystem item a `fresh` (`fresh-cli.sh`) reset would remove.
public struct AgentResetItem: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable { case wrapper, alias, config, data }

    public var kind: Kind
    public var path: String
    public var exists: Bool

    public init(kind: Kind, path: String, exists: Bool) {
        self.kind = kind
        self.path = path
        self.exists = exists
    }

    public var id: String { path }
}

/// Sandbox-exec profile/wrapper state (`sandbox-cli.sh --status`).
public struct AgentSandboxStatus: Sendable, Equatable {
    public var profileExists: Bool
    public var profilePath: String
    public var wrapperReady: Bool
    public var linked: Bool
    public var binPath: String
    public var rules: [String]

    public init(
        profileExists: Bool,
        profilePath: String,
        wrapperReady: Bool,
        linked: Bool,
        binPath: String,
        rules: [String] = []
    ) {
        self.profileExists = profileExists
        self.profilePath = profilePath
        self.wrapperReady = wrapperReady
        self.linked = linked
        self.binPath = binPath
        self.rules = rules
    }

    public var isInstalled: Bool { profileExists && wrapperReady }
}

public enum AgentSetupError: LocalizedError, Equatable, Sendable {
    case unavailable
    case filesystem(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Agent CLI setup is only available on macOS."
        case let .filesystem(message):
            message
        }
    }
}
