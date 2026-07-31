import Combine
import Foundation
import FoundryAPI

@MainActor
public final class ModulesState: ObservableObject {
    public struct LoadingState: Equatable, Sendable {
        public var list = false
        public var detail = false
        public var saving = false
        public var deleting = false
    }

    @Published public private(set) var modules: [FoundryModule] = []
    @Published public private(set) var total = 0
    @Published public private(set) var lastPage = 1
    @Published public private(set) var current: FoundryModule?
    @Published public private(set) var meta: FoundryModuleMeta?
    @Published public private(set) var loading = LoadingState()
    @Published public var search = ""
    @Published public var courseFilter = ""
    @Published public var categoryFilter = ""
    @Published public var difficultyFilter = ""
    @Published public var page = 1
    @Published public var sort = "created_at"
    @Published public var order = "desc"
    @Published public var error: String?

    private let api: FoundryAPI

    public init(api: FoundryAPI) { self.api = api }

    public func loadList() async {
        loading.list = true; error = nil; defer { loading.list = false }
        do {
            let resp = try await api.listModules(courseId: courseFilter, category: categoryFilter, difficulty: difficultyFilter, search: search, page: page, perPage: 20, sort: sort, order: order)
            modules = resp.data; total = resp.total; lastPage = resp.lastPage
        } catch { self.error = "\(error)" }
    }

    public func loadOne(_ id: String) async {
        loading.detail = true; error = nil; defer { loading.detail = false }
        do { current = try await api.getModule(id: id) }
        catch { self.error = "\(error)" }
    }

    public func loadMeta() async {
        do { meta = try await api.moduleMeta() }
        catch { self.error = "\(error)" }
    }

    @discardableResult
    public func create(_ body: FoundryModuleCreateBody) async -> FoundryModule? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { let m = try await api.createModule(body); modules.insert(m, at: 0); return m }
        catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func update(_ id: String, _ body: FoundryModuleUpdateBody) async -> FoundryModule? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do {
            let m = try await api.updateModule(id: id, body)
            if let i = modules.firstIndex(where: { $0.id == id }) { modules[i] = m }
            current = m; return m
        } catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func remove(_ id: String) async -> Bool {
        loading.deleting = true; error = nil; defer { loading.deleting = false }
        do { try await api.deleteModule(id: id); modules.removeAll { $0.id == id }; return true }
        catch { self.error = "\(error)"; return false }
    }
}
