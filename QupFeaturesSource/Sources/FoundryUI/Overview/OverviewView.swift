import DesignSystem
import FoundryAPI
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var state: OverviewState
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                statCards
                charts
                if let cs = state.courseStats, !cs.courses.isEmpty {
                    courseBreakdown(cs)
                }
            }
        }
        .task { await state.load() }
    }

    private var statCards: some View {
        HStack(spacing: 1) {
            StatCard(label: "Courses", value: state.courseStats?.total, loading: state.loading)
            StatCard(label: "KB entries", value: state.kbStats?.total, loading: state.loading)
            StatCard(label: "Modules", value: state.moduleStats?.total, loading: state.loading)
            StatCard(label: "Enrolled", value: state.courseStats?.courses.reduce(0) { $0 + $1.rosterCount }, loading: state.loading)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }

    private var charts: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if let ms = state.moduleStats {
                StatSection(title: "Modules by course") {
                    ForEach(ms.byCourse.prefix(6), id: \.courseId) { row in
                        BarRow(label: row.nameEn, count: row.count, total: ms.total)
                    }
                }
                StatSection(title: "Modules by difficulty") {
                    ForEach(ms.byDifficulty, id: \.label) { row in
                        LabeledRow(label: row.label.capitalized, count: row.count)
                    }
                }
            }
            if let ks = state.kbStats {
                StatSection(title: "KB by course") {
                    ForEach(ks.byCourse, id: \.courseId) { row in
                        LabeledRow(label: row.nameEn, count: row.count)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func courseBreakdown(_ cs: FoundryCourseStats) -> some View {
        VStack(spacing: 0) {
            StatSectionHeader(title: "Course breakdown")
            ForEach(cs.courses, id: \.id) { c in
                HStack {
                    Text(c.nameEn).font(Theme.Typography.body).foregroundStyle(colors.fg)
                    Spacer()
                    Text("\(c.moduleCount) modules").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("\(c.kbCount) KB").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                    Text("\(c.rosterCount) enrolled").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                if c.id != cs.courses.last?.id { SoftDivider() }
            }
        }
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }
}

// MARK: - Sub-views

struct StatCard: View {
    @Environment(\.cupertinoColors) private var colors
    let label: String
    let value: Int?
    let loading: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(label.uppercased())
                .font(Theme.Typography.caption2).foregroundStyle(colors.mutedFg)
            Text(loading ? "—" : (value.map(String.init) ?? "0"))
                .font(.largeTitle.weight(.semibold)).foregroundStyle(colors.fg)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(colors.bg)
    }
}

struct StatSection<Content: View>: View {
    @Environment(\.cupertinoColors) private var colors
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            StatSectionHeader(title: title)
            content.padding(Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .background(colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(colors.border))
    }
}

struct StatSectionHeader: View {
    @Environment(\.cupertinoColors) private var colors
    let title: String

    var body: some View {
        HStack {
            Text(title).font(Theme.Typography.caption.weight(.semibold)).foregroundStyle(colors.fg)
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(colors.bg)
    }
}

struct BarRow: View {
    @Environment(\.cupertinoColors) private var colors
    let label: String
    let count: Int
    let total: Int

    var pct: Double { total > 0 ? min(1, Double(count) / Double(total)) : 0 }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            HStack {
                Text(label).font(Theme.Typography.caption).foregroundStyle(colors.fg).lineLimit(1)
                Spacer()
                Text("\(count)").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(colors.muted)
                    RoundedRectangle(cornerRadius: 4).fill(colors.primary)
                        .frame(width: geo.size.width * pct)
                }
                .frame(height: 4)
            }
            .frame(height: 4)
        }
    }
}

struct LabeledRow: View {
    @Environment(\.cupertinoColors) private var colors
    let label: String
    let count: Int

    var body: some View {
        HStack {
            Text(label).font(Theme.Typography.caption).foregroundStyle(colors.fg)
            Spacer()
            Text("\(count)").font(Theme.Typography.caption.monospacedDigit()).foregroundStyle(colors.mutedFg)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
