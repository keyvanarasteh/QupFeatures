import DesignSystem
import FeatureContracts
import SwiftUI

/// Route destination for "Agent CLI Setup". The real page — installing
/// wrappers under `~/.local/bin`, writing sandbox-exec profiles, and so on —
/// only makes sense on macOS, so iOS sees an explanatory placeholder instead
/// of the interactive controls in `AgentsSetupContentView`.
public struct AgentsSetupView: View {
    #if !os(macOS)
    private static let subtitle = "Install, verify, reset, and sandbox the Antigravity, Claude, Codex, Grok, "
        + "OpenClaude, and OpenCode CLIs."
    private static let unavailableMessage = "This page installs command-line wrappers and sandbox-exec profiles "
        + "on the file system, so it's only available on your Mac."
    #endif

    private let settings: FeatureSettingsClient

    public init(settings: FeatureSettingsClient) {
        self.settings = settings
    }

    public var body: some View {
        #if os(macOS)
        AgentsSetupContentView(settings: settings)
        #else
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader("Agent CLI Setup", subtitle: Self.subtitle, systemImage: "terminal")
                EmptyStateView(title: "macOS Only", message: Self.unavailableMessage, systemImage: "laptopcomputer")
            }
        }
        .navigationTitle("Agent CLI Setup")
        #endif
    }
}
