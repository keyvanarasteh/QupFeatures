import DesignSystem
import FeatureContracts
import FoundryAPI
import Networking
import SwiftUI

public struct FoundryFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.foundry")

    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.foundry.route.root"),
            featureID: Self.featureID,
            title: "Foundry",
            systemImage: "book.closed.fill",
            group: "Features",
            order: 110,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { context in
            AnyView(FoundryRootView(api: FoundryAPI(client: context.qlineClient)))
        })
    }
}

/// Composition root — tabs for Courses / Knowledge Base / Modules / Grades /
/// Overview. Uses a segmented `Picker` like `AdminRootView` (not nested
/// `NavigationStack`).
public struct FoundryRootView: View {
    @StateObject private var overview: OverviewState
    @StateObject private var courses: CoursesState
    @StateObject private var kb: KbState
    @StateObject private var modules: ModulesState
    @StateObject private var grades: GradesState

    public init(api: FoundryAPI) {
        _overview = StateObject(wrappedValue: OverviewState(api: api))
        _courses = StateObject(wrappedValue: CoursesState(api: api))
        _kb = StateObject(wrappedValue: KbState(api: api))
        _modules = StateObject(wrappedValue: ModulesState(api: api))
        _grades = StateObject(wrappedValue: GradesState(api: api))
    }

    public var body: some View {
        FoundryTabView()
            .environmentObject(overview)
            .environmentObject(courses)
            .environmentObject(kb)
            .environmentObject(modules)
            .environmentObject(grades)
            .navigationTitle("Foundry")
    }
}

enum FoundryTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case courses = "Courses"
    case kb = "Knowledge Base"
    case modules = "Modules"
    case grades = "Grades"

    var id: String { rawValue }
}

struct FoundryTabView: View {
    @State private var tab: FoundryTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(FoundryTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch tab {
                case .overview: OverviewView()
                case .courses: CoursesListView()
                case .kb: KbListView()
                case .modules: ModulesListView()
                case .grades: GradesView()
                }
            }
        }
    }
}
