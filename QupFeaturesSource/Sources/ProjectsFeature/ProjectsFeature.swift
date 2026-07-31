import DesignSystem
import FeatureContracts
import Networking
import ProjectsAPI
import QlineAuth
import SwiftUI
import TasksAPI

public struct ProjectsFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.projects")

    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.projects.route.overview"),
            featureID: Self.featureID,
            title: "Projects",
            systemImage: "folder",
            group: "Features",
            order: 102,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { context in
            AnyView(ProjectsRootView(client: context.qlineClient, context: context))
        })
    }
}

/// Composition root. Swaps list ↔ detail via local selection state rather
/// than a nested `NavigationStack`/`NavigationLink` — the app shell already
/// hosts routes in its own stack, and a second one crashes (same landmine
/// `TasksRootView`/`ResearchLabRootView` already document).
public struct ProjectsRootView: View {
    @StateObject private var state: ProjectsState
    let context: FeatureContext

    @State private var selectedProjectId: Int?

    public init(client: APIClient, context: FeatureContext) {
        _state = StateObject(wrappedValue: ProjectsState(
            api: ProjectsAPI(client: client),
            tasksAPI: TasksAPI(client: client)
        ))
        self.context = context
    }

    public var body: some View {
        Group {
            if let selectedProjectId {
                ProjectDetailView(context: context, projectId: selectedProjectId) {
                    self.selectedProjectId = nil
                }
            } else {
                ProjectsListView(context: context) { project in
                    selectedProjectId = project.id
                }
            }
        }
        .environmentObject(state)
    }
}
