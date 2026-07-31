import Combine
import Foundation
import FoundryAPI

@MainActor
public final class GradesState: ObservableObject {
    public struct LoadingState: Equatable, Sendable {
        public var list = false
        public var saving = false
        public var deleting = false
        public var sheet = false
    }

    @Published public private(set) var enrollments: [FoundryEnrollment] = []
    @Published public private(set) var terms: [FoundryTerm] = []
    @Published public private(set) var gradeItems: [FoundryGradeItem] = []
    @Published public private(set) var sheet: FoundryGradeSheet?
    @Published public private(set) var loading = LoadingState()
    @Published public var selectedCourse = ""
    @Published public var selectedYear = ""
    @Published public var selectedSemester = ""
    @Published public var error: String?

    private let api: FoundryAPI

    public init(api: FoundryAPI) { self.api = api }

    public func loadCourses() async {}

    public func loadEnrollments(courseId: String, year: String, semester: String) async {
        loading.list = true; error = nil; defer { loading.list = false }
        do {
            let resp = try await api.listEnrollments(courseId: courseId, academicYear: year, semester: semester)
            enrollments = resp
        } catch { self.error = "\(error)" }
    }

    public func loadTerms(courseId: String) async {
        error = nil
        do {
            let resp = try await api.listEnrollmentTerms(courseId: courseId)
            terms = resp
        } catch { self.error = "\(error)" }
    }

    public func loadGradeItems(courseId: String) async {
        error = nil
        do { gradeItems = try await api.listGradeItems(courseId: courseId) }
        catch { self.error = "\(error)" }
    }

    public func loadSheet(courseId: String, year: String, semester: String) async {
        loading.sheet = true; error = nil; defer { loading.sheet = false }
        do { sheet = try await api.loadGradeSheet(courseId: courseId, academicYear: year, semester: semester) }
        catch { self.error = "\(error)" }
    }

    @discardableResult
    public func enrollStudent(courseId: String, studentId: Int, year: String, semester: String) async -> Int? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do {
            let body = FoundryEnrollmentCreateBody(courseId: courseId, studentId: studentId, academicYear: year, semester: semester)
            return try await api.enrollStudent(body)
        } catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func unenrollStudent(id: Int) async -> Bool {
        loading.deleting = true; error = nil; defer { loading.deleting = false }
        do { try await api.deleteEnrollment(id: id); return true }
        catch { self.error = "\(error)"; return false }
    }

    @discardableResult
    public func createGradeItem(_ body: FoundryGradeItemCreateBody) async -> String? {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { return try await api.createGradeItem(body) }
        catch { self.error = "\(error)"; return nil }
    }

    @discardableResult
    public func updateGradeItem(id: String, _ body: FoundryGradeItemUpdateBody) async -> Bool {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { try await api.updateGradeItem(id: id, body); return true }
        catch { self.error = "\(error)"; return false }
    }

    @discardableResult
    public func deleteGradeItem(id: String) async -> Bool {
        loading.deleting = true; error = nil; defer { loading.deleting = false }
        do { try await api.deleteGradeItem(id: id); return true }
        catch { self.error = "\(error)"; return false }
    }

    @discardableResult
    public func upsertGrades(_ body: FoundryGradeUpsertBody) async -> Bool {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { try await api.upsertGrades(body); return true }
        catch { self.error = "\(error)"; return false }
    }

    @discardableResult
    public func linkProject(rosterId: Int, gradeItemId: String, projectId: Int) async -> Bool {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do {
            try await api.linkGradeProject(FoundryGradeProjectBody(rosterId: rosterId, gradeItemId: gradeItemId, projectId: projectId))
            return true
        } catch { self.error = "\(error)"; return false }
    }

    @discardableResult
    public func unlinkProject(rosterId: Int, gradeItemId: String) async -> Bool {
        loading.saving = true; error = nil; defer { loading.saving = false }
        do { try await api.unlinkGradeProject(rosterId: rosterId, gradeItemId: gradeItemId); return true }
        catch { self.error = "\(error)"; return false }
    }

    public func linkableProjects(rosterId: Int) async -> [FoundryLinkableProject] {
        error = nil
        do { return try await api.linkableProjects(rosterId: rosterId) }
        catch { self.error = "\(error)"; return [] }
    }
}
