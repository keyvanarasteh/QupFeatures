import Foundation
import Networking
import ProjectsAPI
import Testing
@testable import ProjectsFeature

actor ScriptedSession: HTTPSession {
    struct Stub: Sendable {
        var status: Int
        var data: Data
        init(status: Int, data: Data = Data()) { self.status = status; self.data = data }
        static func ok(_ json: String) -> Stub { Stub(status: 200, data: Data(json.utf8)) }
    }

    private var stubs: [Stub]
    init(_ stubs: [Stub]) {
        precondition(!stubs.isEmpty)
        self.stubs = stubs
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let stub = stubs.count > 1 ? stubs.removeFirst() : stubs[0]
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
        return (stub.data, response)
    }
}

private func makeClient(session: HTTPSession) -> APIClient {
    APIClient(
        baseURL: URL(string: "https://example.test")!,
        session: session,
        retryPolicy: .none,
        encoder: {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        },
        decoder: {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        },
        sleep: { _ in }
    )
}

@Suite @MainActor struct ProjectsFeatureTests {
    @Test func loadingStateDefaultsToAllFalse() {
        let loading = ProjectsState.LoadingState()
        #expect(loading.list == false)
        #expect(loading.saving == false)
    }

    @Test func loadProjectsPopulatesListFromAPI() async throws {
        let json = """
        {"projects":[{"id":1,"name":"Qrofessor","slug":"qrofessor","description":null,"is_private":false,"is_active":true,"tags":null,"repository_url":null,"programming_language":null,"framework":null,"version":null,"default_branch":null,"type_display":null,"type_color":null,"status_display":null,"status_color":null,"owner_name":null,"member_count":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]}
        """
        let session = ScriptedSession([.ok(json)])
        let state = ProjectsState(api: ProjectsAPI(client: makeClient(session: session)))
        await state.loadProjects()
        #expect(state.projects.count == 1)
        #expect(state.projects.first?.name == "Qrofessor")
        #expect(state.error == nil)
    }

    @Test func createProjectInsertsAtFront() async throws {
        let json = """
        {"project":{"id":9,"name":"New","slug":"new","description":null,"is_private":false,"is_active":true,"tags":null,"repository_url":null,"programming_language":null,"framework":null,"version":null,"default_branch":null,"type_display":null,"type_color":null,"status_display":null,"status_color":null,"owner_name":null,"member_count":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}}
        """
        let session = ScriptedSession([.ok(json)])
        let state = ProjectsState(api: ProjectsAPI(client: makeClient(session: session)))
        let created = await state.createProject(ProjectCreate(name: "New", projectTypeId: 1, statusId: 1))
        #expect(created?.id == 9)
        #expect(state.projects.first?.id == 9)
    }

    @Test func loadAdminStatsPopulatesStatsFromAPI() async throws {
        let json = """
        {"total":10,"active":7,"inactive":3,"private":4,"public":6,"with_repo":8,"without_repo":2,
        "repo_coverage":80,"deploy_auto":5,"deploy_on_push":3,"created_week":1,"created_month":4,
        "members":12,"task_total":20,"task_done":15,"task_completion":75,
        "by_type":[{"label":"Web App","color":"#6366f1","count":6}],
        "by_status":[{"label":"Active","color":"#22c55e","count":7}],
        "by_lang":[{"label":"Swift","count":9}],
        "by_framework":[{"label":"SwiftUI","count":5}],
        "by_package_mgr":[{"label":"SPM","count":9}],
        "top_owners":[{"name":"Ada","email":"ada@example.test","count":3}],
        "recent":[{"id":1,"name":"Qrofessor","slug":"qrofessor","is_private":false,"is_active":true,
        "repository_url":null,"type_display":"Web App","type_color":"#6366f1","status_display":"Active",
        "status_color":"#22c55e","owner_name":"Ada","updated_at":"2026-01-01T00:00:00Z"}]}
        """
        let session = ScriptedSession([.ok(json)])
        let state = ProjectsState(api: ProjectsAPI(client: makeClient(session: session)))
        await state.loadAdminStats()
        #expect(state.adminStats?.total == 10)
        #expect(state.adminStats?.byType.first?.label == "Web App")
        #expect(state.adminStats?.recent.first?.name == "Qrofessor")
        #expect(state.loading.adminStats == false)
        #expect(state.error == nil)
    }

    @Test func loadRepoOwnerDiagnosticsPopulatesIssuesFromAPI() async throws {
        let json = """
        {"summary":{"total":5,"github":4,"non_github":1,"ok":3,"missing":1},
        "issues":[{"project_id":1,"name":"Qrofessor","slug":"qrofessor",
        "repository_url":"https://github.com/acme/qrofessor","owner":"acme",
        "candidate_count":1,"candidates":[{"user_id":2,"user_name":"Ada"}]}]}
        """
        let session = ScriptedSession([.ok(json)])
        let state = ProjectsState(api: ProjectsAPI(client: makeClient(session: session)))
        await state.loadRepoOwnerDiagnostics()
        #expect(state.repoOwnerDiagnostics?.summary.missing == 1)
        #expect(state.repoOwnerDiagnostics?.issues.first?.name == "Qrofessor")
        #expect(state.repoOwnerDiagnostics?.issues.first?.candidates.first?.userName == "Ada")
        #expect(state.error == nil)
    }

    @Test func repoOwnerLinkSeedPrefillsGitHubOwner() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let projectJSON = """
        {"id":1,"name":"Qrofessor","slug":"qrofessor","description":null,"is_private":false,"is_active":true,"tags":null,"repository_url":"https://github.com/acme/qrofessor","programming_language":null,"framework":null,"version":null,"default_branch":null,"type_display":null,"type_color":null,"status_display":null,"status_color":null,"owner_name":"Ada","member_count":null,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """
        let issueJSON = """
        {"project_id":1,"name":"Qrofessor","slug":"qrofessor","repository_url":"https://github.com/acme/qrofessor","owner":"acme","candidate_count":1,"candidates":[{"user_id":2,"user_name":"Ada"}]}
        """
        let project = try decoder.decode(Project.self, from: Data(projectJSON.utf8))
        let issue = try decoder.decode(RepoOwnerIssue.self, from: Data(issueJSON.utf8))

        let seed = ProjectRepoOwnerLinkSeed(issue: issue, project: project)

        #expect(seed?.label == "Qrofessor repo owner")
        #expect(seed?.username == "acme")
        #expect(seed?.displayName == "Qrofessor")
        #expect(seed?.profileUrl == "https://github.com/acme")
        #expect(seed?.email == "")
    }
}
