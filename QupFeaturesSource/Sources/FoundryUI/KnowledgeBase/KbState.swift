import Combine
import Foundation
import FoundryAPI

@MainActor
public final class KbState: ObservableObject {
    public struct LoadingState: Equatable, Sendable {
        public var list = false
        public var detail = false
        public var saving = false
        public var deleting = false
    }

    @Published public private(set) var entries: [FoundryKbEntry] = []
    @Published public private(set) var total = 0
    @Published public private(set) var lastPage = 1
    @Published public private(set) var current: FoundryKbEntry?
    @Published public private(set) var loading = LoadingState()
    @Published public var search = ""
    @Published public var courseFilter = ""
    @Published public var page = 1
    @Published public var sort = "created_at"
    @Published public var order = "desc"
    @Published public var error: String?

    private let api: FoundryAPI

    public init(api: FoundryAPI) { self.api = api }

    public func loadList() async {
        loading.list = true; error = nil; defer { loading.list = false }
        do {
            let resp = try await api.listKbEntries(courseId: courseFilter, search: search, page: page, perPage: 20, sort: sort, order: order)
            entries = resp.data; total = resp.total; lastPage = resp.lastPage
        } catch { self.error = "\(error)" }
    }

    public func loadOne(_ id: String) async {
        loading.detail = true; error = nil; defer { loading.detail = false }
        do { current = try await api.getKbEntry(id: id) }
        catch { self.error = "\(error)" }
    }

    @discardableResult
    public func create(_ body: FoundryKbCreateBody) async -> FoundryKbEntry? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { let e = try await api.createKbEntry(body); entries.insert(e, at: 0); return e }
        catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func update(_ id: String, _ body: FoundryKbUpdateBody) async -> FoundryKbEntry? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do {
            let e = try await api.updateKbEntry(id: id, body)
            if let i = entries.firstIndex(where: { $0.id == id }) { entries[i] = e }
            current = e; return e
        } catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func remove(_ id: String) async -> Bool {
        loading.deleting = true; error = nil; defer { loading.deleting = false }
        do { try await api.deleteKbEntry(id: id); entries.removeAll { $0.id == id }; return true }
        catch { self.error = "\(error)"; return false }
    }
}
