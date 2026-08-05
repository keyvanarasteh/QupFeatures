import DesignSystem
import FeatureContracts
import Networking
import SwiftUI
import WikiAPI

// MARK: - Feature module

public struct WikiFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.wiki")

    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.wiki.route.overview"),
            featureID: Self.featureID,
            title: "Wiki",
            systemImage: "book.closed",
            group: "Features",
            order: 95,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { context in
            AnyView(WikiRootView(client: context.qlineClient))
        })
    }
}

// MARK: - Composition root

/// Browse surface over `WikiViewModel` + existing WikiUI building blocks.
/// Avoids a nested `NavigationStack` — the host shell already owns navigation.
public struct WikiRootView: View {
    @State private var viewModel: WikiViewModel
    @State private var activePath = ""
    @State private var selectedIds: Set<Int> = []
    @Environment(\.cupertinoColors) private var colors
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(client: APIClient) {
        _viewModel = State(initialValue: WikiViewModel(client: client))
    }

    public var body: some View {
        VStack(spacing: 0) {
            filterBar
            if let error = viewModel.error {
                errorBanner(error)
            }
            contentBody
        }
        .background(colors.bg)
        .navigationTitle("Wiki")
        .task {
            await viewModel.loadTree()
            await viewModel.loadSections()
        }
        .refreshable {
            await viewModel.loadTree(force: true)
            await viewModel.loadSections()
            await reloadCurrentDestination()
        }
    }

    // MARK: - Chrome

    private var filterBar: some View {
        WikiFilterBarView(
            query: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ),
            tags: Binding(
                get: { viewModel.searchTags },
                set: { viewModel.searchTags = $0 }
            ),
            sectionId: Binding(
                get: { viewModel.searchSectionId },
                set: { viewModel.searchSectionId = $0 }
            ),
            status: Binding(
                get: { viewModel.searchStatus },
                set: { viewModel.searchStatus = $0 }
            ),
            visibility: Binding(
                get: { viewModel.searchVisibility },
                set: { viewModel.searchVisibility = $0 }
            ),
            sort: Binding(
                get: { viewModel.searchSort },
                set: { viewModel.searchSort = $0 }
            ),
            order: Binding(
                get: { viewModel.searchOrder },
                set: { viewModel.searchOrder = $0 }
            ),
            sections: viewModel.sections,
            onChange: {
                Task { await viewModel.search() }
            }
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(Theme.Typography.caption)
            Spacer()
            Button {
                viewModel.clearError()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(colors.danger)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(colors.danger.opacity(0.1))
    }

    // MARK: - Body

    @ViewBuilder
    private var contentBody: some View {
        let isCompact = sizeClass == .compact
        if isCompact {
            VStack(spacing: 0) {
                WikiSidebarView(
                    tree: viewModel.tree,
                    activePath: activePath,
                    onNavigate: handleNavigate
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                mainPane
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                WikiSidebarView(
                    tree: viewModel.tree,
                    activePath: activePath,
                    onNavigate: handleNavigate
                )
                Divider()
                mainPane
            }
        }
    }

    @ViewBuilder
    private var mainPane: some View {
        Group {
            if viewModel.loading.tree && viewModel.tree.isEmpty {
                ProgressView("Loading wiki…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching {
                searchResultsPane
            } else if let article = viewModel.currentArticle {
                articlePane(article)
            } else if viewModel.currentSection != nil {
                sectionPane
            } else {
                EmptyStateView(
                    title: "Wiki",
                    message: "Pick a section from the sidebar or search articles.",
                    systemImage: "book.closed"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isSearching: Bool {
        !viewModel.searchQuery.isEmpty
            || !viewModel.searchTags.isEmpty
            || viewModel.searchSectionId != nil
            || viewModel.searchStatus != nil
            || viewModel.searchVisibility != nil
            || !viewModel.searchResults.isEmpty
    }

    private var searchResultsPane: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Search results")
                    .font(Theme.Typography.headline)
                Spacer()
                if viewModel.loading.search {
                    ProgressView().controlSize(.small)
                }
                Button("Clear") {
                    viewModel.clearSearch()
                }
                .buttonStyle(.ghost)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)

            articleList(
                articles: viewModel.searchResults,
                total: viewModel.searchTotal,
                loading: viewModel.loading.search
            )
        }
    }

    private func articlePane(_ article: WikiArticle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    viewModel.currentArticle = nil
                    if let section = viewModel.currentSection {
                        activePath = "/wiki/\(section.slug)"
                    } else {
                        activePath = ""
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.ghost)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            WikiArticleReaderView(article: article)
        }
    }

    private var sectionPane: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let section = viewModel.currentSection {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(section.title)
                        .font(Theme.Typography.title)
                    if let description = section.description, !description.isEmpty {
                        Text(description)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(colors.mutedFg)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }

            if viewModel.loading.section && viewModel.sectionArticles.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                articleList(
                    articles: viewModel.sectionArticles,
                    total: viewModel.sectionTotal,
                    loading: viewModel.loading.section
                )
            }
        }
    }

    private func articleList(articles: [WikiArticleStub], total: Int, loading: Bool) -> some View {
        Group {
            if loading && articles.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if articles.isEmpty {
                EmptyStateView(
                    title: "No Articles",
                    message: "No articles match this view.",
                    systemImage: "doc.text"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(articles) { article in
                        Button {
                            Task {
                                _ = await viewModel.loadArticle(id: article.id)
                                if let sectionSlug = sectionSlug(for: article) {
                                    activePath = "/wiki/\(sectionSlug)/\(article.slug)"
                                }
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(article.title)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(colors.fg)
                                    HStack(spacing: Theme.Spacing.xs) {
                                        WikiStatusBadge(article.status)
                                        WikiVisibilityBadge(article.visibility)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(colors.mutedFg)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .overlay(alignment: .bottom) {
                    if total > articles.count {
                        Text("Showing \(articles.count) of \(total)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.mutedFg)
                            .padding(Theme.Spacing.sm)
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    private func handleNavigate(_ path: String) {
        activePath = path
        selectedIds = []
        Task { await navigate(to: path) }
    }

    private func navigate(to path: String) async {
        // Paths from the sidebar: "/wiki/{sectionSlug}" or "/wiki/{sectionSlug}/{articleSlug}"
        let parts = path
            .split(separator: "/")
            .map(String.init)
            .filter { $0 != "wiki" && !$0.isEmpty }

        guard !parts.isEmpty else {
            viewModel.currentArticle = nil
            viewModel.currentSection = nil
            return
        }

        let sectionSlug = parts[0]
        if parts.count >= 2 {
            let articleSlug = parts[1]
            _ = await viewModel.loadArticleBySlug(sectionSlug: sectionSlug, slug: articleSlug)
            if let section = findSection(slug: sectionSlug, in: viewModel.tree) {
                await viewModel.loadSection(id: section.id)
            }
            return
        }

        viewModel.currentArticle = nil
        if let section = findSection(slug: sectionSlug, in: viewModel.tree) {
            await viewModel.loadSection(id: section.id)
        }
    }

    private func reloadCurrentDestination() async {
        guard !activePath.isEmpty else { return }
        await navigate(to: activePath)
    }

    private func findSection(slug: String, in tree: [WikiSectionTree]) -> WikiSectionTree? {
        for node in tree {
            if node.slug == slug { return node }
            if let found = findSection(slug: slug, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func sectionSlug(for article: WikiArticleStub) -> String? {
        if let slug = article.sectionSlug { return slug }
        if let current = viewModel.currentSection { return current.slug }
        return findSectionContaining(articleId: article.id, in: viewModel.tree)?.slug
    }

    private func findSectionContaining(articleId: Int, in tree: [WikiSectionTree]) -> WikiSectionTree? {
        for node in tree {
            if node.articles.contains(where: { $0.id == articleId }) {
                return node
            }
            if let found = findSectionContaining(articleId: articleId, in: node.children) {
                return found
            }
        }
        return nil
    }
}
