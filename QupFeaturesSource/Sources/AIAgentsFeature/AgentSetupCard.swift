#if os(macOS)
import DesignSystem
import SwiftUI

/// One agent's card in `AgentsSetupContentView` — status, the six
/// `setup-agents.sh` actions (setup/check/verify/reset/sandbox/homepage),
/// and an expandable detail list of the last check/verify report.
struct AgentSetupCard: View {
    @Environment(\.cupertinoColors) private var colors
    @EnvironmentObject private var store: AgentSetupStore

    let target: AgentSetupTarget
    @State private var isExpanded = false
    @State private var isSandboxExpanded = false
    @State private var pendingReset = false

    private var report: AgentCheckReport? { store.reports[target] }
    private var sandbox: AgentSandboxStatus? { store.sandboxStatuses[target] }
    private var isBusy: Bool { store.isBusy(target) }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                actionRow
                if let report, !report.items.isEmpty {
                    SoftDivider()
                    DisclosureGroup(isExpanded: $isExpanded) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            ForEach(report.items) { CheckItemRow(item: $0) }
                        }
                        .padding(.top, Theme.Spacing.sm)
                    } label: {
                        Text("\(report.passCount) pass, \(report.failCount) fail")
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(colors.mutedFg)
                    }
                }
                SoftDivider()
                sandboxSection
            }
        }
        .confirmationDialog(
            "Reset \(target.displayName)?",
            isPresented: $pendingReset,
            titleVisibility: .visible
        ) {
            Button("Remove Wrapper, Config & Data", role: .destructive) {
                Task { await store.reset(target) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let items = store.resetPreview(for: target).filter(\.exists)
            if items.isEmpty {
                Text("Nothing is installed for \(target.displayName) yet.")
            } else {
                Text("This removes: \(items.map(\.path).joined(separator: ", "))")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: target.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(target.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, height: 36)
                .background(
                    target.tint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(target.displayName)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(colors.fg)
                    statusBadge
                }
                Text(aliasSuffixedCommand)
                    .font(Theme.Typography.footnote.monospaced())
                    .foregroundStyle(colors.mutedFg)
            }
            Spacer(minLength: 0)
            Button {
                store.openHomepage(target)
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.mutedFg)
            .help("Open \(target.displayName)'s homepage")
        }
    }

    private var aliasSuffixedCommand: String {
        guard let alias = target.alias else { return target.command }
        return "\(target.command) · \(alias)"
    }

    private var statusBadge: some View {
        guard let report else { return StatusBadge("Unknown", tone: .neutral) }
        if report.items.isEmpty { return StatusBadge("Unknown", tone: .neutral) }
        return report.isHealthy
            ? StatusBadge("Installed", tone: .success)
            : StatusBadge("Not Installed", tone: .warning)
    }

    private var actionRow: some View {
        AdaptiveStack(spacing: Theme.Spacing.sm) {
            CupertinoSecondaryButton("Setup", systemImage: "gearshape", isLoading: isBusy, expands: false) {
                Task { await store.setup(target) }
            }
            Button("Check") { Task { await store.check(target) } }
                .buttonStyle(.secondary)
                .disabled(isBusy)
            Button("Verify") { Task { await store.verify(target) } }
                .buttonStyle(.secondary)
                .disabled(isBusy)
            Button("Reset", role: .destructive) { pendingReset = true }
                .buttonStyle(.destructive)
                .disabled(isBusy)
        }
    }

    @ViewBuilder
    private var sandboxSection: some View {
        DisclosureGroup(isExpanded: $isSandboxExpanded) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let sandbox {
                    if sandbox.isInstalled {
                        Text(sandbox.profilePath)
                            .font(Theme.Typography.caption.monospaced())
                            .foregroundStyle(colors.mutedFg)
                        ForEach(sandbox.rules, id: \.self) { rule in
                            Text(rule)
                                .font(Theme.Typography.caption.monospaced())
                                .foregroundStyle(colors.mutedFg)
                        }
                    } else {
                        Text("No sandbox-exec profile installed for \(target.command) yet.")
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(colors.mutedFg)
                    }
                }
                HStack(spacing: Theme.Spacing.sm) {
                    if sandbox?.isInstalled == true {
                        Button("Uninstall Sandbox") { Task { await store.uninstallSandbox(target) } }
                            .buttonStyle(.destructive)
                    } else {
                        Button("Install Sandbox") { Task { await store.installSandbox(target) } }
                            .buttonStyle(.secondary)
                    }
                }
                .disabled(isBusy)
            }
            .padding(.top, Theme.Spacing.sm)
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "lock.shield")
                Text(sandbox?.isInstalled == true ? "Sandbox — installed" : "Sandbox — not installed")
            }
            .font(Theme.Typography.footnote)
            .foregroundStyle(colors.mutedFg)
        }
        .onAppear { store.refreshSandboxStatus(target) }
    }
}

private struct CheckItemRow: View {
    @Environment(\.cupertinoColors) private var colors
    let item: AgentCheckItem

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: item.status == .pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(item.status == .pass ? colors.success : colors.danger)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(item.title)
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(colors.fg)
                Text(item.detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            Spacer(minLength: 0)
        }
    }
}
#endif
