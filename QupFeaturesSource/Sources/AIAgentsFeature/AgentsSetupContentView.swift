#if os(macOS)
import DesignSystem
import FeatureContracts
import SwiftUI

/// The real Agent CLI Setup page — macOS only. Reimplements every feature of
/// the `SETUP/{antigravity,claude,codex,grok,openclaude,opencode}/*.sh`
/// toolkit as native, configurable, interactive controls: install (`setup`),
/// status (`check`), full verification (`verify`), reset (`fresh`), a
/// sandbox-exec profile + wrapper (`sandbox`), and the provider homepage
/// (`download`'s primary artifact).
struct AgentsSetupContentView: View {
    private static let subtitle = "Install, verify, reset, and sandbox the Antigravity, Claude, Codex, Grok, "
        + "OpenClaude, and OpenCode CLIs on this Mac."
    private static let installLocationHelp = "Wrapper binaries install under <location>/bin. Config and data "
        + "always stay under ~/.config and ~/.local/share, matching the shell scripts."

    @Environment(\.cupertinoColors) private var colors
    @StateObject private var store: AgentSetupStore
    @State private var prefixDraft: String = ""
    @State private var isBulkBusy = false

    init(settings: FeatureSettingsClient) {
        _store = StateObject(wrappedValue: AgentSetupStore(settings: settings))
    }

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader("Agent CLI Setup", subtitle: Self.subtitle, systemImage: "terminal")

                configCard
                bulkActionsRow

                VStack(spacing: Theme.Spacing.md) {
                    ForEach(AgentSetupTarget.allCases) { target in
                        AgentSetupCard(target: target)
                    }
                }
                .environmentObject(store)

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Agent CLI Setup")
        .task {
            await store.load()
            prefixDraft = store.prefixPath
        }
        .onChange(of: store.prefixPath) { _, newValue in prefixDraft = newValue }
        .alert("Agent CLI Setup", isPresented: .init(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "Unknown error")
        }
    }

    private var configCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Install Location").font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
                Text(Self.installLocationHelp)
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(colors.mutedFg)
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("Install location", text: $prefixDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await store.updatePrefix(prefixDraft) } }
                    CupertinoSecondaryButton("Use Default", expands: false) {
                        Task { await store.resetPrefixToDefault() }
                    }
                }
            }
        }
    }

    private var bulkActionsRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            CupertinoSecondaryButton("Check All", systemImage: "checklist", isLoading: isBulkBusy, expands: false) {
                Task { isBulkBusy = true; await store.checkAll(); isBulkBusy = false }
            }
            CupertinoSecondaryButton("Verify All", systemImage: "checkmark.shield", isLoading: isBulkBusy, expands: false) {
                Task { isBulkBusy = true; await store.verifyAll(); isBulkBusy = false }
            }
            Spacer(minLength: 0)
        }
    }
}
#endif
