import Combine
import Foundation
import ProjectsAPI
import TasksAPI

/// Ports `projectStore.svelte.ts`'s reactive state onto `ProjectsAPI`, matching
/// `TasksState`'s `@MainActor` `ObservableObject` shape. `ProjectsAPI` has no
/// pagination (`listProjects` returns the full matching set, not a page), so
/// unlike `TasksState` there's no `total`/`totalPages`/`setPage`.
@MainActor
public final class ProjectsState: ObservableObject {
    public struct LoadingState: Equatable, Sendable {
        public var list = false
        public var meta = false
        public var project = false
        public var saving = false
        public var adminStats = false
        public var adminActivity = false
        public var diagnostics = false
        public var related = false
        public var linkedAccounts = false
    }

    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var types: [ProjectType] = []
    @Published public private(set) var statuses: [ProjectStatus] = []
    @Published public private(set) var roles: [ProjectRole] = []
    @Published public private(set) var allTags: [String] = []
    @Published public var filter = ProjectFilter()
    @Published public private(set) var currentProject: Project?
    @Published public private(set) var loading = LoadingState()
    @Published public var error: String?
    @Published public private(set) var adminStats: AdminProjectStats?
    @Published public private(set) var adminActivity: [ProjectActivityLog] = []
    @Published public private(set) var repoOwnerDiagnostics: RepoOwnerDiagnostics?
    @Published public private(set) var projectStats: ProjectStats?
    @Published public private(set) var projectActivity: [ProjectActivityLog] = []
    @Published public private(set) var linkedTasks: [TaskRecord] = []
    @Published public private(set) var linkedAccounts: [ProjectMemberLinkedAccounts] = []

    private let api: ProjectsAPI
    private let tasksAPI: TasksAPI?

    public init(api: ProjectsAPI, tasksAPI: TasksAPI? = nil) {
        self.api = api
        self.tasksAPI = tasksAPI
    }

    private func setErr(_ error: any Error) {
        self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }

    public func clearErr() { error = nil }

    // MARK: - List

    public func loadProjects(_ patch: ProjectFilter? = nil) async {
        if let patch { filter = patch }
        loading.list = true
        error = nil
        defer { loading.list = false }
        do {
            projects = try await api.listProjects(filter: filter)
        } catch {
            setErr(error)
        }
    }

    public func setFilter(_ patch: (inout ProjectFilter) -> Void) async {
        patch(&filter)
        await loadProjects()
    }

    public func loadMeta() async {
        loading.meta = true
        defer { loading.meta = false }
        async let loadedTypes = api.listTypes()
        async let loadedStatuses = api.listStatuses()
        async let loadedRoles = api.listRoles()
        async let loadedTags = api.listProjectTags()
        do {
            types = try await loadedTypes
            statuses = try await loadedStatuses
            roles = try await loadedRoles
            allTags = try await loadedTags
        } catch {
            setErr(error)
        }
    }

    /// Resolve a deep link like `qcupertino://projects/{slug}` without a
    /// numeric id — `getProject(slug:)` hits the same detail route/shape as
    /// `getProject(id:)`.
    @discardableResult
    public func loadProject(slug: String) async -> Project? {
        loading.project = true
        error = nil
        defer { loading.project = false }
        do {
            let project = try await api.getProject(slug: slug)
            currentProject = project
            await loadProjectRelated(id: project.id)
            return project
        } catch {
            setErr(error)
            return nil
        }
    }

    public func createType(_ input: ProjectTypeCreate) async -> Bool {
        await mutateMeta { _ = try await self.api.createType(input) }
    }

    public func updateType(id: Int, _ input: ProjectTypeUpdate) async -> Bool {
        await mutateMeta { try await self.api.updateType(id: id, input) }
    }

    public func deleteType(id: Int) async -> Bool {
        await mutateMeta { try await self.api.deleteType(id: id) }
    }

    public func createStatus(_ input: ProjectStatusCreate) async -> Bool {
        await mutateMeta { _ = try await self.api.createStatus(input) }
    }

    public func updateStatus(id: Int, _ input: ProjectStatusUpdate) async -> Bool {
        await mutateMeta { try await self.api.updateStatus(id: id, input) }
    }

    public func deleteStatus(id: Int) async -> Bool {
        await mutateMeta { try await self.api.deleteStatus(id: id) }
    }

    public func createRole(_ input: ProjectRoleCreate) async -> Bool {
        await mutateMeta { _ = try await self.api.createRole(input) }
    }

    public func updateRole(id: Int, _ input: ProjectRoleUpdate) async -> Bool {
        await mutateMeta { try await self.api.updateRole(id: id, input) }
    }

    public func deleteRole(id: Int) async -> Bool {
        await mutateMeta { try await self.api.deleteRole(id: id) }
    }

    private func mutateMeta(_ mutation: () async throws -> Void) async -> Bool {
        loading.saving = true
        error = nil
        defer { loading.saving = false }
        do {
            try await mutation()
            await loadMeta()
            return true
        } catch {
            setErr(error)
            return false
        }
    }

    // MARK: - Single project

    @discardableResult
    public func loadProject(id: Int) async -> Project? {
        loading.project = true
        error = nil
        defer { loading.project = false }
        do {
            let project = try await api.getProject(id: id)
            currentProject = project
            await loadProjectRelated(id: id)
            return project
        } catch {
            setErr(error)
            return nil
        }
    }

    @discardableResult
    public func updateProject(id: Int, _ payload: ProjectUpdate) async -> Project? {
        loading.saving = true
        error = nil
        defer { loading.saving = false }
        do {
            let project = try await api.updateProject(id: id, payload)
            currentProject = project
            if let index = projects.firstIndex(where: { $0.id == id }) { projects[index] = project }
            await loadProjectRelated(id: id)
            return project
        } catch {
            setErr(error)
            return nil
        }
    }

    public func deleteProject(id: Int) async -> Bool {
        loading.saving = true
        error = nil
        defer { loading.saving = false }
        do {
            try await api.deleteProject(id: id)
            projects.removeAll { $0.id == id }
            if currentProject?.id == id { currentProject = nil }
            return true
        } catch {
            setErr(error)
            return false
        }
    }

    public func addMember(projectId: Int, userId: Int, roleId: Int) async -> Bool {
        loading.saving = true
        error = nil
        defer { loading.saving = false }
        do {
            try await api.addMember(projectId: projectId, userId: userId, roleId: roleId)
            currentProject = try await api.getProject(id: projectId)
            await loadProjectRelated(id: projectId)
            return true
        } catch {
            setErr(error)
            return false
        }
    }

    public func removeMember(projectId: Int, userId: Int) async -> Bool {
        loading.saving = true
        error = nil
        defer { loading.saving = false }
        do {
            try await api.removeMember(projectId: projectId, userId: userId)
            currentProject = try await api.getProject(id: projectId)
            await loadProjectRelated(id: projectId)
            return true
        } catch {
            setErr(error)
            return false
        }
    }

    public func loadProjectRelated(id: Int) async {
        loading.related = true
        defer { loading.related = false }
        async let statsResult = api.projectStats(id: id)
        async let activityResult = api.projectActivity(id: id)
        do {
            projectStats = try await statsResult
            projectActivity = try await activityResult
        } catch {
            setErr(error)
        }
        await loadLinkedAccounts(projectId: id)
        guard let tasksAPI else { return }
        do {
            linkedTasks = try await tasksAPI.listTasks(filter: TaskFilter(projectID: id, perPage: 50)).data
        } catch {
            setErr(error)
        }
    }

    /// Members' collaborator identities (GitHub handles, etc.) — the primary
    /// use case is collecting handles for collaborator invites.
    public func loadLinkedAccounts(projectId: Int, provider: String? = nil, teamOnly: Bool = false) async {
        loading.linkedAccounts = true
        defer { loading.linkedAccounts = false }
        do {
            linkedAccounts = teamOnly
                ? try await api.projectTeamLinkedAccounts(projectId: projectId, provider: provider)
                : try await api.projectLinkedAccounts(projectId: projectId, provider: provider)
        } catch {
            setErr(error)
        }
    }

    @discardableResult
    public func createProject(_ payload: ProjectCreate) async -> Project? {
        loading.saving = true
        error = nil
        defer { loading.saving = false }
        do {
            let project = try await api.createProject(payload)
            projects.insert(project, at: 0)
            return project
        } catch {
            setErr(error)
            return nil
        }
    }

    // MARK: - Admin

    public func loadAdminStats() async {
        loading.adminStats = true
        error = nil
        defer { loading.adminStats = false }
        do {
            adminStats = try await api.adminStats()
        } catch {
            setErr(error)
        }
    }

    public func loadAdminActivity(limit: Int = 20) async {
        loading.adminActivity = true
        error = nil
        defer { loading.adminActivity = false }
        do {
            adminActivity = try await api.adminActivity(limit: limit)
        } catch {
            setErr(error)
        }
    }

    public func loadRepoOwnerDiagnostics() async {
        loading.diagnostics = true
        error = nil
        defer { loading.diagnostics = false }
        do {
            repoOwnerDiagnostics = try await api.diagnoseRepoOwners()
        } catch {
            setErr(error)
        }
    }
}
