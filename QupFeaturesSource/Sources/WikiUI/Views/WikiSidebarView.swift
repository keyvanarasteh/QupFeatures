import SwiftUI
import DesignSystem
import WikiAPI

/// Tree navigation sidebar for the wiki.
///
/// Sections collapse/expand. Active article path is highlighted.
/// On compact width (phone), renders as a slide-in drawer.
public struct WikiSidebarView: View {
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.horizontalSizeClass) private var sizeClass

    let tree: [WikiSectionTree]
    let activePath: String
    var collapsed: Bool
    var onNavigate: ((String) -> Void)?

    @State private var expandedSections: Set<Int> = []
    @State private var showDrawer = false

    public init(
        tree: [WikiSectionTree],
        activePath: String = "",
        collapsed: Bool = false,
        onNavigate: ((String) -> Void)? = nil
    ) {
        self.tree = tree
        self.activePath = activePath
        self.collapsed = collapsed
        self.onNavigate = onNavigate
    }

    public var body: some View {
        let isCompact = sizeClass == .compact

        Group {
            if isCompact {
                Button { showDrawer = true } label: {
                    Image(systemName: "sidebar.left")
                        .font(.body)
                }
                .buttonStyle(.secondary)
                .help("Wiki sidebar")
                .sheet(isPresented: $showDrawer) {
                    ScrollView {
                        sidebarList
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            } else {
                ScrollView {
                    sidebarList
                }
                .frame(maxWidth: collapsed ? 60 : 260)
                .background(colors.sidebarBg)
            }
        }
        .onAppear { autoExpandActivePath() }
    }

    @ViewBuilder
    private var sidebarList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            // Header
            if !collapsed {
                Label("Wiki", systemImage: "book.closed")
                    .font(Theme.Typography.title)
                    .foregroundStyle(colors.fg)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
            }

            ForEach(tree) { section in
                sidebarRow(section, indent: 0)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    /// Returns a section expand/collapse row.
    private func sidebarRow(_ section: WikiSectionTree, indent: Int) -> AnyView {
        let isExpanded = expandedSections.contains(section.id)
        let hasChildren = !section.children.isEmpty
        let hasArticles = !section.articles.isEmpty

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    if hasChildren || hasArticles {
                        if isExpanded {
                            expandedSections.remove(section.id)
                        } else {
                            expandedSections.insert(section.id)
                        }
                    }
                    onNavigate?("/wiki/\(section.slug)")
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        if collapsed {
                            IconView(icon: section.icon)
                                .frame(width: 32, height: 32)
                                .foregroundStyle(colors.primary)
                        } else {
                            if hasChildren {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 12)
                            } else {
                                Spacer().frame(width: 12)
                            }

                            IconView(icon: section.icon)
                                .font(.caption)
                                .frame(width: 18)
                                .foregroundStyle(colors.primary)

                            Text(section.title)
                                .font(Theme.Typography.subheadline)
                                .lineLimit(1)
                                .foregroundStyle(isActive(section.slug) ? colors.primary : colors.fg)

                            Spacer()

                            if let count = section.articleCount {
                                Text("\(count)")
                                    .font(Theme.Typography.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.leading, CGFloat(indent * 16) + Theme.Spacing.sm)
                    .padding(.trailing, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        isActive(section.slug)
                            ? colors.primarySoft
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(collapsed ? section.title : "")

                if isExpanded && !collapsed {
                    ForEach(section.articles) { article in
                        articleRow(article, sectionSlug: section.slug, indent: indent + 1)
                    }
                    ForEach(section.children) { child in
                        sidebarRow(child, indent: indent + 1)
                    }
                }
            }
        )
    }

    /// Returns an article link row.
    private func articleRow(_ article: WikiArticleStub, sectionSlug: String, indent: Int) -> AnyView {
        let path = "/wiki/\(sectionSlug)/\(article.slug)"
        return AnyView(
            Button {
                onNavigate?(path)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(article.title)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(isActive(path) ? colors.primary : .secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.leading, CGFloat(indent * 16) + Theme.Spacing.lg)
                .padding(.trailing, Theme.Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    isActive(path)
                        ? colors.primarySoft
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        )
    }

    private func isActive(_ path: String) -> Bool {
        activePath.contains(path) && !path.isEmpty
    }

    private func autoExpandActivePath() {
        guard !activePath.isEmpty, !tree.isEmpty else { return }
        for section in tree {
            if activePath.contains(section.slug) {
                expandedSections.insert(section.id)
            }
            for child in section.children {
                if activePath.contains(child.slug) {
                    expandedSections.insert(section.id)
                    expandedSections.insert(child.id)
                }
            }
        }
    }
}
