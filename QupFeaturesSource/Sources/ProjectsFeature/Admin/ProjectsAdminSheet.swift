import DesignSystem
import ProjectsAPI
import SwiftUI

/// Ported from `routes/admin/projects/+page.svelte`: overview, activity,
/// project types/statuses/roles CRUD, and repo-owner diagnostics. Flagged repo
/// owners are corrected from the project detail helper, where account linking
/// and project membership can be completed together.
///
/// No parameters on `init()` — presented bare via `.sheet(isPresented:) {
/// ProjectsAdminSheet() }` from `ProjectsListView`, relying on the
/// `ProjectsState` `ProjectsRootView` already injects into the subtree.
public struct ProjectsAdminSheet: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case stats = "Stats"
        case types = "Types"
        case statuses = "Statuses"
        case roles = "Roles"
        case activity = "Activity"
        case diagnostics = "Diagnostics"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: ProjectsState

    @State private var tab: Tab = .stats

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)

                Group {
                    switch tab {
                    case .stats: AdminStatsTabView()
                    case .types: ProjectTypesAdminView()
                    case .statuses: ProjectStatusesAdminView()
                    case .roles: ProjectRolesAdminView()
                    case .activity: AdminActivityTabView()
                    case .diagnostics: AdminDiagnosticsTabView()
                    }
                }
            }
            .navigationTitle("Projects Admin")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            async let meta: () = state.loadMeta()
            async let stats: () = state.loadAdminStats()
            async let activity: () = state.loadAdminActivity()
            async let diagnostics: () = state.loadRepoOwnerDiagnostics()
            _ = await (meta, stats, activity, diagnostics)
        }
    }
}

// MARK: - Stats tab

private struct AdminStatsTabView: View {
    @EnvironmentObject private var state: ProjectsState
    @Environment(\.cupertinoColors) private var colors

    private let gridColumns = [GridItem(.adaptive(minimum: 130), spacing: Theme.Spacing.md)]

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if let error = state.error {
                    Text(error).foregroundStyle(colors.danger)
                }
                if state.loading.adminStats && state.adminStats == nil {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let stats = state.adminStats {
                    overview(stats)
                    details(stats)
                    breakdowns(stats)
                    topOwners(stats)
                    recent(stats)
                } else {
                    EmptyStateView(
                        title: "No stats",
                        message: "Admin stats aren't available yet.",
                        systemImage: "chart.bar"
                    )
                }
            }
        }
    }

    private func overview(_ stats: AdminProjectStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Overview", systemImage: "chart.bar.doc.horizontal")
            LazyVGrid(columns: gridColumns, spacing: Theme.Spacing.md) {
                StatTile(label: "Total", value: "\(stats.total)")
                StatTile(label: "Active", value: "\(stats.active)", tone: .success)
                StatTile(label: "Inactive", value: "\(stats.inactive)", tone: .neutral)
                StatTile(label: "Private", value: "\(stats.private)")
                StatTile(label: "Public", value: "\(stats.public)")
                StatTile(label: "Repo coverage", value: percentString(stats.repoCoverage))
                StatTile(label: "Task completion", value: percentString(stats.taskCompletion), tone: .info)
            }
        }
    }

    private func details(_ stats: AdminProjectStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Details", systemImage: "list.bullet.rectangle")
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    detailRow("With repo", "\(stats.withRepo)")
                    detailRow("Without repo", "\(stats.withoutRepo)")
                    detailRow("Auto-deploy", "\(stats.deployAuto)")
                    detailRow("Deploy on push", "\(stats.deployOnPush)")
                    detailRow("Created this week", "\(stats.createdWeek)")
                    detailRow("Created this month", "\(stats.createdMonth)")
                    detailRow("Members", "\(stats.members)")
                    detailRow("Tasks (done / total)", "\(stats.taskDone) / \(stats.taskTotal)")
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.subheadline).foregroundStyle(colors.mutedFg)
            Spacer()
            Text(value).font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
        }
    }

    private func breakdowns(_ stats: AdminProjectStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Breakdowns", systemImage: "chart.pie")
            CardView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    breakdownGroup("By type", stats.byType.map { BreakdownRow(label: $0.label, count: $0.count, color: $0.color) })
                    breakdownGroup("By status", stats.byStatus.map { BreakdownRow(label: $0.label, count: $0.count, color: $0.color) })
                    breakdownGroup("By language", stats.byLang.map { BreakdownRow(label: $0.label, count: $0.count, color: nil) })
                    breakdownGroup("By framework", stats.byFramework.map { BreakdownRow(label: $0.label, count: $0.count, color: nil) })
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownGroup(_ title: String, _ rows: [BreakdownRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(Theme.Typography.captionEmphasized).foregroundStyle(colors.mutedFg)
                ForEach(rows) { row in
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(row.color.flatMap(Color.init(hexString:)) ?? colors.primary)
                            .frame(width: 8, height: 8)
                        Text(row.label).font(Theme.Typography.callout).foregroundStyle(colors.fg)
                        Spacer()
                        Text("\(row.count)").font(Theme.Typography.callout).foregroundStyle(colors.mutedFg)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topOwners(_ stats: AdminProjectStats) -> some View {
        if !stats.topOwners.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader("Top owners", systemImage: "person.2")
                CardView {
                    VStack(spacing: 0) {
                        ForEach(Array(stats.topOwners.enumerated()), id: \.offset) { index, owner in
                            HStack {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(owner.name).font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
                                    if let email = owner.email {
                                        Text(email).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                                    }
                                }
                                Spacer()
                                StatusBadge("\(owner.count)", tone: .info)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            if index != stats.topOwners.count - 1 { SoftDivider() }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recent(_ stats: AdminProjectStats) -> some View {
        if !stats.recent.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader("Recently updated", systemImage: "clock")
                CardView {
                    VStack(spacing: 0) {
                        ForEach(Array(stats.recent.enumerated()), id: \.element.id) { index, project in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Text(project.name).font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
                                        if !project.isActive { StatusBadge("Inactive", tone: .neutral) }
                                        Image(systemName: project.isPrivate ? "lock.fill" : "globe")
                                            .font(.caption2)
                                            .foregroundStyle(colors.mutedFg)
                                    }
                                    HStack(spacing: Theme.Spacing.xs) {
                                        if let statusDisplay = project.statusDisplay {
                                            StatusBadge(statusDisplay, tone: .info)
                                        }
                                        if let ownerName = project.ownerName {
                                            Text(ownerName).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                                        }
                                    }
                                }
                                Spacer()
                                Text(relativeDateString(project.updatedAt))
                                    .font(Theme.Typography.caption2)
                                    .foregroundStyle(colors.mutedFg)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            if index != stats.recent.count - 1 { SoftDivider() }
                        }
                    }
                }
            }
        }
    }

    private func percentString(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct BreakdownRow: Identifiable {
    let label: String
    let count: Int
    let color: String?
    var id: String { label }
}

private struct StatTile: View {
    @Environment(\.cupertinoColors) private var colors
    let label: String
    let value: String
    var tone: StatusTone = .neutral

    var body: some View {
        CardView(padding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(label.uppercased())
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(colors.mutedFg)
                Text(value)
                    .font(Theme.Typography.title)
                    .foregroundStyle(tone == .neutral ? colors.fg : tone.color(in: colors))
            }
        }
    }
}

// MARK: - Activity tab

private struct AdminActivityTabView: View {
    @EnvironmentObject private var state: ProjectsState
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader("Recent activity", subtitle: "Latest actions across all projects.", systemImage: "clock.arrow.circlepath")
                if let error = state.error {
                    Text(error).foregroundStyle(colors.danger)
                }
                if state.loading.adminActivity && state.adminActivity.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else if state.adminActivity.isEmpty {
                    EmptyStateView(
                        title: "No activity",
                        message: "Nothing has happened yet.",
                        systemImage: "clock"
                    )
                } else {
                    CardView {
                        VStack(spacing: 0) {
                            ForEach(Array(state.adminActivity.enumerated()), id: \.element.id) { index, log in
                                ActivityRow(log: log)
                                if index != state.adminActivity.count - 1 { SoftDivider() }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ActivityRow: View {
    @Environment(\.cupertinoColors) private var colors
    let log: ProjectActivityLog

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Circle()
                .fill(colors.mutedFg.opacity(0.4))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(log.description ?? "\(log.activityType) · \(log.activityAction)")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(colors.fg)
                HStack(spacing: Theme.Spacing.xs) {
                    if let projectName = log.projectName {
                        Text(projectName).font(Theme.Typography.caption).foregroundStyle(colors.primary)
                    }
                    Text("\(log.userName ?? "System") · \(relativeDateString(log.createdAt))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Diagnostics tab

private struct AdminDiagnosticsTabView: View {
    @EnvironmentObject private var state: ProjectsState
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "Repo owner diagnostics",
                    subtitle: "Flags GitHub-linked projects whose repo owner isn't a linked team member. Read-only — open the project to resolve.",
                    systemImage: "checkmark.shield"
                )
                if let error = state.error {
                    Text(error).foregroundStyle(colors.danger)
                }
                if state.loading.diagnostics && state.repoOwnerDiagnostics == nil {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let diagnostics = state.repoOwnerDiagnostics {
                    summaryRow(diagnostics.summary)
                    if diagnostics.issues.isEmpty {
                        EmptyStateView(
                            title: "All clear",
                            message: "Every GitHub project's repo owner is linked to a team member.",
                            systemImage: "checkmark.circle"
                        )
                    } else {
                        CardView {
                            VStack(spacing: 0) {
                                ForEach(Array(diagnostics.issues.enumerated()), id: \.element.id) { index, issue in
                                    IssueRow(issue: issue)
                                    if index != diagnostics.issues.count - 1 { SoftDivider() }
                                }
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "No diagnostics",
                        message: "Diagnostics aren't available yet.",
                        systemImage: "checkmark.shield"
                    )
                }
            }
        }
    }

    private func summaryRow(_ summary: RepoOwnerDiagnosticsSummary) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            CupertinoChip("\(summary.total) total")
            CupertinoChip("\(summary.github) GitHub")
            CupertinoChip("\(summary.ok) OK", tint: colors.success)
            CupertinoChip("\(summary.missing) missing", tint: colors.warning)
        }
    }
}

private struct IssueRow: View {
    @Environment(\.cupertinoColors) private var colors
    let issue: RepoOwnerIssue

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(colors.warning)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text(issue.name).font(Theme.Typography.bodyEmphasized).foregroundStyle(colors.fg)
                    Text(issue.slug).font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                }
                if let owner = issue.owner {
                    Text("owner @\(owner)").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                }
                if let repositoryUrl = issue.repositoryUrl {
                    Text(repositoryUrl).font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg).lineLimit(1)
                }
                if issue.candidates.isEmpty {
                    StatusBadge("No candidates", tone: .neutral)
                } else {
                    Text("Candidates: \(issue.candidates.map(\.userName).joined(separator: ", "))")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.primary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Shared helpers

/// Best-effort ISO8601 → medium-date-style formatting; falls back to the raw
/// wire string when parsing fails (mirrors the source's tolerant `new
/// Date(...)` usage).
private func relativeDateString(_ iso: String) -> String {
    let parsers: [ISO8601DateFormatter] = [
        {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }(),
        {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }(),
    ]
    guard let date = parsers.lazy.compactMap({ $0.date(from: iso) }).first else {
        return iso
    }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// Note: `Color(hexString:)` (for `ProjectStatBreakdown.color`/`byType`'s hex
// strings) is already defined as an internal `Color` extension in
// `Views/ProjectsListView.swift` — same module, reused here as-is.
