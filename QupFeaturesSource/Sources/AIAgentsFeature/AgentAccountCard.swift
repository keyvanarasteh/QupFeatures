import DesignSystem
import SwiftUI

struct AgentAccountCard: View {
    @Environment(\.cupertinoColors) private var colors

    let account: AgentAccount
    let isCheckingUsage: Bool
    let isCLIInstalled: Bool
    let isSettingUpCLI: Bool
    let onCheckUsage: () -> Void
    let onSetUpCLI: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShowCheatsheet: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                if !account.limits.isEmpty {
                    SoftDivider()
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(account.limits) { limit in
                            limitRow(limit)
                        }
                    }
                }
                if let notes = account.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(colors.mutedFg)
                }
                #if os(macOS)
                if account.provider.setupTarget != nil {
                    SoftDivider()
                    cliStatusRow
                }
                #endif
                HStack(spacing: Theme.Spacing.sm) {
                    Spacer(minLength: 0)
                    #if os(macOS)
                    if [.claude, .codex, .grok].contains(account.provider) {
                        Button(action: onCheckUsage) {
                            Label(isCheckingUsage ? "Checking…" : "Check Usage", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.secondary)
                        .disabled(isCheckingUsage)
                    }
                    #endif
                    Button("Edit", action: onEdit).buttonStyle(.secondary)
                    Button("Delete", role: .destructive, action: onDelete).buttonStyle(.destructive)
                }
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var cliStatusRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: isCLIInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isCLIInstalled ? colors.success : colors.warning)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(isCLIInstalled ? "CLI installed on this Mac" : "CLI not installed on this Mac")
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(colors.mutedFg)
                if isCLIInstalled {
                    Text("Verify, reset, or sandbox it from Agent CLI Setup in the sidebar.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                }
            }
            Spacer(minLength: 0)
            if !isCLIInstalled {
                Button(action: onSetUpCLI) {
                    Label(isSettingUpCLI ? "Setting up…" : "Set Up CLI", systemImage: "gearshape")
                }
                .buttonStyle(.secondary)
                .disabled(isSettingUpCLI)
            }
        }
    }
    #endif

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: account.provider.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(account.provider.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 36, height: 36)
                .background(account.provider.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(account.nickname)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(colors.fg)
                    if let planTier = account.planTier, !planTier.isEmpty {
                        StatusBadge(planTier, tone: .info)
                    }
                }
                Text(account.email)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(colors.mutedFg)
                Text(account.provider.vendorName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            Spacer(minLength: 0)
            if account.provider == .claude {
                Button(action: onShowCheatsheet) {
                    Image(systemName: "book.pages")
                }
                .buttonStyle(.plain)
                .foregroundStyle(colors.mutedFg)
                .help("Claude usage cheatsheet")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func limitRow(_ limit: UsageLimit) -> some View {
        let tint = limit.severity.color(in: colors)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Text(limit.displayLabel)
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(colors.fg)
                Spacer()
                Text("\(Int(limit.usedPercent.rounded()))%")
                    .font(Theme.Typography.captionEmphasized)
                    .foregroundStyle(tint)
                Text(resetText(for: limit))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            ProgressView(value: limit.usedPercent, total: 100)
                .tint(tint)
        }
    }

    private func resetText(for limit: UsageLimit) -> String {
        guard let resetsAt = limit.resetsAt else { return "No reset set" }
        if resetsAt <= .now { return "Resets pending" }
        return "Resets \(Self.relativeFormatter.localizedString(for: resetsAt, relativeTo: .now))"
    }
}
