import DesignSystem
import Foundation
import SwiftUI

/// One CLI managed by the local Setup page — mirrors the shell toolkit under
/// `SETUP/<name>/` (`setup-cli.sh`, `check-cli.sh`, `verify-cli.sh`,
/// `fresh-cli.sh`, `sandbox-cli.sh`, `download.sh`). Each case carries the
/// same wrapper command name, alias, env-var prefix, and homepage that
/// script's `CMD`/`ALIAS`/`sources.md` used, so the macOS Setup page and the
/// shell scripts stay interchangeable.
public enum AgentSetupTarget: String, CaseIterable, Identifiable, Sendable {
    case antigravity, claude, codex, grok, openclaude, opencode

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .antigravity: "Antigravity"
        case .claude: "Claude"
        case .codex: "Codex"
        case .grok: "Grok"
        case .openclaude: "OpenClaude"
        case .opencode: "OpenCode"
        }
    }

    /// The installed wrapper's command name (`CMD` in the shell scripts).
    public var command: String {
        switch self {
        case .antigravity: "anti"
        case .claude: "claude2"
        case .codex: "codex"
        case .grok: "grok-x"
        case .openclaude: "openclaude"
        case .opencode: "opencode"
        }
    }

    /// Short alias symlink installed alongside the wrapper, if any (`ALIAS`).
    public var alias: String? {
        switch self {
        case .openclaude: "oclc"
        case .opencode: "opcode"
        default: nil
        }
    }

    /// Upper-cased prefix used for the wrapper's exported
    /// `<PREFIX>_CONFIG_DIR` / `<PREFIX>_DATA_DIR` environment variables.
    public var envPrefix: String {
        switch self {
        case .antigravity: "ANTI"
        case .claude: "CLAUDE"
        case .codex: "CODEX"
        case .grok: "GROK"
        case .openclaude: "OPENCLAUDE"
        case .opencode: "OPENCODE"
        }
    }

    /// The provider's download/homepage (`sources.md`) — opened in the
    /// default browser by the "Open Homepage" action, the interactive
    /// counterpart of `download.sh`'s primary artifact.
    public var homepage: URL {
        switch self {
        case .antigravity: URL(string: "https://antigravity.com")!
        case .claude: URL(string: "https://claude.ai/download")!
        case .codex: URL(string: "https://chatgpt.com/codex/")!
        case .grok: URL(string: "https://grok.com")!
        case .openclaude: URL(string: "https://github.com/Gitlawb/openclaude")!
        case .opencode: URL(string: "https://github.com/opencode-ai/opencode")!
        }
    }

    public var systemImage: String {
        switch self {
        case .antigravity: "diamond.fill"
        case .claude: "sparkle"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .grok: "bolt.fill"
        case .openclaude: "cpu"
        case .opencode: "curlybraces"
        }
    }

    private var tintHex: UInt64 {
        switch self {
        case .antigravity: 0x4285F4
        case .claude: 0xD97757
        case .codex: 0x10A37F
        case .grok: 0x000000
        case .openclaude: 0xD97757
        case .opencode: 0x8B5CF6
        }
    }

    public var tint: Color { Color(hex: tintHex) }

    /// The tracked-account provider this setup target corresponds to, if any.
    /// `openclaude` and `opencode` have no dedicated `AgentProvider` case.
    public var accountProvider: AgentProvider? {
        switch self {
        case .antigravity: .gemini
        case .claude: .claude
        case .codex: .codex
        case .grok: .grok
        case .openclaude, .opencode: nil
        }
    }
}

public extension AgentProvider {
    /// The CLI this tracked-account provider installs/verifies through the
    /// Agent CLI Setup page, if this provider has a dedicated one. `kimi` and
    /// `other` accounts have no corresponding local CLI toolkit.
    var setupTarget: AgentSetupTarget? {
        AgentSetupTarget.allCases.first { $0.accountProvider == self }
    }
}
