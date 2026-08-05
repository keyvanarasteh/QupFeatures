import Foundation
import WikiAPI
import Networking

/// Observable state and actions for the wiki feature.
///
/// Wraps `WikiService` calls and owns all UI-facing state (loaded data, loading
/// flags, pagination, filters). Callers create one instance and pass it down
/// via SwiftUI environment or as an `@EnvironmentObject`.
///
/// The view model is deliberately on `@MainActor` so published properties can
/// drive SwiftUI without explicit `DispatchQueue.main.async` hops.
@MainActor
@Observable
public final class WikiViewModel {
    private let client: APIClient

    // MARK: - Tree / navigation

    public var tree: [WikiSectionTree] = []
    public var treeLoaded = false

    public var sections: [WikiSection] = []

    // MARK: - Current section view

    public var currentSection: WikiSection?
    public var sectionChildren: [WikiSection] = []
    public var sectionArticles: [WikiArticleStub] = []
    public var sectionTotal = 0
    public var sectionPage = 1
    public var sectionSize = 50
    public var sectionStatusFilter: WikiStatus?

    // MARK: - Current article view

    public var currentArticle: WikiArticle?
    public var currentArticleSection: SectionRef?
    public var revisions: [WikiRevisionStub] = []
    public var currentRevision: WikiRevision?
    public var accessGrants: [WikiArticleAccess] = []

    // MARK: - Search

    public var searchResults: [WikiArticleStub] = []
    public var searchTotal = 0
    public var searchPages = 0
    public var searchPage = 1
    public var searchSize = 20
    public var searchQuery = ""
    public var searchSectionId: Int?
    public var searchTags: [String] = []
    public var searchStatus: WikiStatus?
    public var searchVisibility: WikiVisibility?
    public var searchSort: String = "relevance"
    public var searchOrder: String = "desc"

    // MARK: - Loading / error

    public private(set) var loading = LoadingState()
    public private(set) var error: String?

    public struct LoadingState: Sendable {
        public var tree = false
        public var sections = false
        public var section = false
        public var article = false
        public var search = false
        public var saving = false
        public var deleting = false
        public var revisions = false
        public var access = false
    }

    // MARK: - Init

    public init(client: APIClient) {
        self.client = client
    }

    // MARK: - Helpers

    private func setError(_ e: any Error) {
        error = e.localizedDescription
    }

    public func clearError() {
        error = nil
    }

    // MARK: - Tree / navigation

    public func loadTree(force: Bool = false) async {
        guard treeLoaded == false || force else { return }
        loading.tree = true
        clearError()
        do {
            let data = try await WikiService.loadTree(client: client)
            tree = data.tree
            treeLoaded = true
        } catch {
            setError(error)
        }
        loading.tree = false
    }

    public func loadSections() async {
        loading.sections = true
        clearError()
        do {
            let data = try await WikiService.loadSections(client: client)
            sections = data.sections
        } catch {
            setError(error)
        }
        loading.sections = false
    }

    // MARK: - Section CRUD

    public func loadSection(id: Int, page: Int? = nil, size: Int? = nil, status: WikiStatus? = nil) async {
        loading.section = true
        clearError()
        if let page { sectionPage = page }
        if let size { sectionSize = size }
        if let status { sectionStatusFilter = status }
        do {
            let data = try await WikiService.loadSection(
                id: id,
                page: sectionPage,
                size: sectionSize,
                status: sectionStatusFilter,
                client: client
            )
            currentSection = data.section
            sectionChildren = data.children
            sectionArticles = data.articles
            sectionTotal = data.total
            sectionPage = data.page
            sectionSize = data.size
        } catch {
            setError(error)
        }
        loading.section = false
    }

    @discardableResult
    public func createSection(_ payload: WikiSectionCreate) async -> WikiSection? {
        loading.saving = true
        clearError()
        do {
            let section = try await WikiService.createSection(payload, client: client)
            treeLoaded = false
            loading.saving = false
            return section
        } catch {
            setError(error)
            loading.saving = false
            return nil
        }
    }

    @discardableResult
    public func updateSection(id: Int, _ payload: WikiSectionUpdate) async -> WikiSection? {
        loading.saving = true
        clearError()
        do {
            let section = try await WikiService.updateSection(id: id, payload, client: client)
            if currentSection?.id == id { currentSection = section }
            treeLoaded = false
            loading.saving = false
            return section
        } catch {
            setError(error)
            loading.saving = false
            return nil
        }
    }

    @discardableResult
    public func deleteSection(id: Int, force: Bool = false) async -> Bool {
        loading.deleting = true
        clearError()
        do {
            try await WikiService.deleteSection(id: id, force: force, client: client)
            if currentSection?.id == id { currentSection = nil }
            treeLoaded = false
            loading.deleting = false
            return true
        } catch {
            setError(error)
            loading.deleting = false
            return false
        }
    }

    // MARK: - Article CRUD

    @discardableResult
    public func loadArticle(id: Int) async -> WikiArticle? {
        loading.article = true
        clearError()
        do {
            let data = try await WikiService.loadArticle(id: id, client: client)
            currentArticle = data.article
            currentArticleSection = data.section
            revisions = []
            accessGrants = []
            loading.article = false
            return data.article
        } catch {
            setError(error)
            loading.article = false
            return nil
        }
    }

    @discardableResult
    public func loadArticleBySlug(sectionSlug: String, slug: String) async -> WikiArticle? {
        loading.article = true
        clearError()
        do {
            let data = try await WikiService.loadArticleBySlug(sectionSlug: sectionSlug, slug: slug, client: client)
            currentArticle = data.article
            currentArticleSection = nil
            loading.article = false
            return data.article
        } catch {
            setError(error)
            loading.article = false
            return nil
        }
    }

    @discardableResult
    public func createArticle(_ payload: WikiArticleCreate) async -> WikiArticle? {
        loading.saving = true
        clearError()
        do {
            let data = try await WikiService.createArticle(payload, client: client)
            treeLoaded = false
            loading.saving = false
            return data.article
        } catch {
            setError(error)
            loading.saving = false
            return nil
        }
    }

    @discardableResult
    public func updateArticle(id: Int, _ payload: WikiArticleUpdate) async -> WikiArticle? {
        loading.saving = true
        clearError()
        do {
            let (article, revisionSaved) = try await WikiService.updateArticle(id: id, payload, client: client)
            if currentArticle?.id == id { currentArticle = article }
            if revisionSaved { revisions = [] }
            treeLoaded = false
            loading.saving = false
            return article
        } catch {
            setError(error)
            loading.saving = false
            return nil
        }
    }

    @discardableResult
    public func deleteArticle(id: Int, hard: Bool = false) async -> Bool {
        loading.deleting = true
        clearError()
        do {
            try await WikiService.deleteArticle(id: id, hard: hard, client: client)
            if currentArticle?.id == id { currentArticle = nil }
            sectionArticles.removeAll { $0.id == id }
            treeLoaded = false
            loading.deleting = false
            return true
        } catch {
            setError(error)
            loading.deleting = false
            return false
        }
    }

    // MARK: - Revisions

    public func loadRevisions(articleId: Int) async {
        loading.revisions = true
        clearError()
        do {
            let data = try await WikiService.loadRevisions(articleId: articleId, client: client)
            revisions = data.revisions
        } catch {
            setError(error)
        }
        loading.revisions = false
    }

    @discardableResult
    public func loadRevision(articleId: Int, version: Int) async -> WikiRevision? {
        loading.revisions = true
        clearError()
        do {
            let data = try await WikiService.loadRevision(articleId: articleId, version: version, client: client)
            currentRevision = data.revision
            loading.revisions = false
            return data.revision
        } catch {
            setError(error)
            loading.revisions = false
            return nil
        }
    }

    // MARK: - Access grants

    public func loadAccessGrants(articleId: Int) async {
        loading.access = true
        clearError()
        do {
            let data = try await WikiService.loadAccessGrants(articleId: articleId, client: client)
            accessGrants = data.grants
        } catch {
            setError(error)
        }
        loading.access = false
    }

    @discardableResult
    public func grantAccess(_ payload: WikiAccessGrant) async -> WikiArticleAccess? {
        loading.access = true
        clearError()
        do {
            let grant = try await WikiService.grantAccess(payload, client: client)
            if let idx = accessGrants.firstIndex(where: { $0.userId == payload.userId }) {
                accessGrants[idx] = grant
            } else {
                accessGrants.append(grant)
            }
            loading.access = false
            return grant
        } catch {
            setError(error)
            loading.access = false
            return nil
        }
    }

    @discardableResult
    public func revokeAccess(grantId: Int) async -> Bool {
        loading.access = true
        clearError()
        do {
            try await WikiService.revokeAccess(grantId: grantId, client: client)
            accessGrants.removeAll { $0.id == grantId }
            loading.access = false
            return true
        } catch {
            setError(error)
            loading.access = false
            return false
        }
    }

    // MARK: - Search

    public func search(allowEmpty: Bool = false) async {
        let hasQ = searchQuery.count >= 2
        let hasTags = !searchTags.isEmpty
        let hasFilter = searchSectionId != nil || searchStatus != nil || searchVisibility != nil
        guard hasQ || hasTags || hasFilter || allowEmpty else {
            searchResults = []
            searchTotal = 0
            searchPages = 0
            return
        }
        loading.search = true
        clearError()
        do {
            let data = try await WikiService.search(
                query: searchQuery,
                sectionId: searchSectionId,
                tags: searchTags,
                status: searchStatus,
                visibility: searchVisibility,
                sort: searchSort,
                order: searchOrder,
                page: searchPage,
                size: searchSize,
                client: client
            )
            searchResults = data.results
            searchTotal = data.total
            searchPages = data.pages
            searchPage = data.page
            searchSize = data.size
        } catch {
            setError(error)
        }
        loading.search = false
    }

    public func setSearchPage(_ page: Int) {
        searchPage = page
        Task { await search() }
    }

    public func clearSearch() {
        searchResults = []
        searchTotal = 0
        searchPage = 1
        searchQuery = ""
        searchSectionId = nil
        searchTags = []
        searchStatus = nil
        searchVisibility = nil
        searchSort = "relevance"
        searchOrder = "desc"
    }

    // MARK: - Admin

    @discardableResult
    public func reorderSections(_ items: [WikiReorderPayload]) async -> Bool {
        loading.saving = true
        clearError()
        do {
            try await WikiService.reorderSections(items, client: client)
            treeLoaded = false
            loading.saving = false
            return true
        } catch {
            setError(error)
            loading.saving = false
            return false
        }
    }

    @discardableResult
    public func bulkAction(action: String, ids: [Int], visibility: String? = nil, sectionId: Int? = nil) async -> Bool {
        loading.saving = true
        clearError()
        do {
            try await WikiService.bulkAction(action: action, ids: ids, visibility: visibility, sectionId: sectionId, client: client)
            treeLoaded = false
            loading.saving = false
            return true
        } catch {
            setError(error)
            loading.saving = false
            return false
        }
    }
}

/// Re-export SectionRef from WikiArticleResponse for convenience.
public typealias SectionRef = WikiArticleResponse.SectionRef
