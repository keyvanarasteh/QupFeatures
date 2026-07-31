import Combine
import Foundation
import FoundryAPI

@MainActor
public final class CoursesState: ObservableObject {
    public struct LoadingState: Equatable, Sendable {
        public var list = false
        public var detail = false
        public var saving = false
        public var deleting = false
        public var stats = false
    }

    @Published public private(set) var courses: [FoundryCourse] = []
    @Published public private(set) var total = 0
    @Published public private(set) var lastPage = 1
    @Published public private(set) var current: FoundryCourse?
    @Published public private(set) var stats: FoundryCourseStats?
    @Published public private(set) var loading = LoadingState()
    @Published public var search = ""
    @Published public var page = 1
    @Published public var sort = "created_at"
    @Published public var order = "desc"
    @Published public var error: String?

    private let api: FoundryAPI

    public init(api: FoundryAPI) { self.api = api }

    public func loadList() async {
        loading.list = true; error = nil; defer { loading.list = false }
        do {
            let resp = try await api.listCourses(search: search, page: page, perPage: 20, sort: sort, order: order)
            courses = resp.data; total = resp.total; lastPage = resp.lastPage
        } catch { self.error = "\(error)" }
    }

    public func loadOne(_ id: String) async {
        loading.detail = true; error = nil; defer { loading.detail = false }
        do { current = try await api.getCourse(id: id) }
        catch { self.error = "\(error)" }
    }

    @discardableResult
    public func create(_ body: FoundryCourseCreateBody) async -> FoundryCourse? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { let c = try await api.createCourse(body); courses.insert(c, at: 0); return c }
        catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func update(_ id: String, _ body: FoundryCourseUpdateBody) async -> FoundryCourse? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do {
            let c = try await api.updateCourse(id: id, body)
            if let i = courses.firstIndex(where: { $0.id == id }) { courses[i] = c }
            current = c; return c
        } catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func remove(_ id: String) async -> Bool {
        loading.deleting = true; error = nil; defer { loading.deleting = false }
        do { try await api.deleteCourse(id: id); courses.removeAll { $0.id == id }; return true }
        catch { self.error = "\(error)"; return false }
    }

    public func loadStats() async {
        loading.stats = true; error = nil; defer { loading.stats = false }
        do { stats = try await api.courseStats() }
        catch { self.error = "\(error)" }
    }
}
