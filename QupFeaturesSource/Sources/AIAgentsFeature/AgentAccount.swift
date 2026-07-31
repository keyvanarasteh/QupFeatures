import DesignSystem
import Foundation
import SwiftUI

public enum AgentProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude, codex, gemini, grok, kimi, other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .gemini: "Gemini / Antigravity"
        case .grok: "Grok"
        case .kimi: "Kimi-AI"
        case .other: "Other"
        }
    }

    public var vendorName: String {
        switch self {
        case .claude: "Anthropic"
        case .codex: "OpenAI"
        case .gemini: "Google"
        case .grok: "xAI"
        case .kimi: "Moonshot"
        case .other: "Custom"
        }
    }

    public var systemImage: String {
        switch self {
        case .claude: "sparkle"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .gemini: "diamond.fill"
        case .grok: "bolt.fill"
        case .kimi: "moon.stars.fill"
        case .other: "cpu"
        }
    }

    public var tintHex: UInt64 {
        switch self {
        case .claude: 0xD97757
        case .codex: 0x10A37F
        case .gemini: 0x4285F4
        case .grok: 0x000000
        case .kimi: 0x33A06F
        case .other: 0x8B5CF6
        }
    }

    public var tint: Color { Color(hex: tintHex) }
}

public enum LimitWindow: String, Codable, CaseIterable, Identifiable, Sendable {
    case session, daily, weekly, monthly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .session: "Session"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}

public struct UsageLimit: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var window: LimitWindow
    public var usedPercent: Double
    public var resetsAt: Date?
    public var label: String?

    public init(
        id: UUID = UUID(),
        window: LimitWindow,
        usedPercent: Double,
        resetsAt: Date? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.window = window
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
        self.label = label
    }

    public var displayLabel: String { label?.isEmpty == false ? label! : window.displayName }

    public var severity: StatusTone {
        switch usedPercent {
        case ..<60: .success
        case ..<85: .warning
        default: .danger
        }
    }

    public var isNearLimit: Bool { usedPercent >= 85 }
}

public struct AgentAccount: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var provider: AgentProvider
    public var nickname: String
    public var email: String
    public var planTier: String?
    public var notes: String?
    public var limits: [UsageLimit]
    public var remindBeforeReset: Bool
    public var alertNearLimit: Bool
    public var createdAt: Date
    public var updatedAt: Date
    /// Links this local record to its `provider: "ai-agent"` row in core-api's
    /// generic credentials store, once synced. `nil` means the account only
    /// exists in this device's local cache (created offline, or sync disabled).
    /// Usage `limits` are never synced — each device tracks its own CLI locally.
    public var remoteCredentialID: Int?

    public init(
        id: UUID = UUID(),
        provider: AgentProvider,
        nickname: String,
        email: String,
        planTier: String? = nil,
        notes: String? = nil,
        limits: [UsageLimit] = [],
        remindBeforeReset: Bool = true,
        alertNearLimit: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        remoteCredentialID: Int? = nil
    ) {
        self.id = id
        self.provider = provider
        self.nickname = nickname
        self.email = email
        self.planTier = planTier
        self.notes = notes
        self.limits = limits
        self.remindBeforeReset = remindBeforeReset
        self.alertNearLimit = alertNearLimit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteCredentialID = remoteCredentialID
    }

    /// Soonest upcoming reset across every limit window, if any is set.
    public var nextReset: Date? {
        limits.compactMap(\.resetsAt).filter { $0 > .now }.min()
    }

    public var hasNearLimitWarning: Bool { limits.contains { $0.isNearLimit } }
}
