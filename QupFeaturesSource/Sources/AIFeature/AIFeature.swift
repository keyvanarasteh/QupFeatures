import AIAPI
import FeatureContracts
import Networking
import SwiftUI

public struct AIFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.ai")
    public init() {}

    @MainActor public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        for (index, section) in AISection.allCases.enumerated() {
            try registry.register(route: FeatureRouteContribution(
                id: FeatureRouteID("tech.qline.ai.route.\(section.rawValue)"), featureID: Self.featureID,
                title: section.title, systemImage: section.icon, group: "Features", order: 105 + index,
                access: .init(
                    requiresSignIn: true,
                    anyOf: [
                        .init(allowedRoles: ["admin"]),
                        .init(permissions: ["ai_access"]),
                    ],
                    deniedPresentation: .locked
                )
            ) { context in
                AnyView(AIRootView(
                    client: context.qlineClient,
                    settings: context.settings(Self.featureID),
                    initialSection: section
                ))
            })
        }
    }
}

public struct AIRootView: View {
    @StateObject private var state: AIState
    @State private var section: AISection
    @Environment(\.scenePhase) private var scenePhase

    public init(client: APIClient) {
        self.init(client: client, settings: nil, initialSection: .overview)
    }

    public init(client: APIClient, settings: FeatureSettingsClient?) {
        self.init(client: client, settings: settings, initialSection: .overview)
    }

    init(client: APIClient, settings: FeatureSettingsClient?, initialSection: AISection) {
        let cache = settings.map { AILocalCacheStore(settings: $0) }
        _state = StateObject(wrappedValue: AIState(api: AIAPI(client: client), cache: cache))
        _section = State(initialValue: initialSection)
    }
    public var body: some View {
#if os(macOS)
        content
#else
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("AI section", selection: $section) {
                                ForEach(AISection.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                            }
                        } label: { Label(section.title, systemImage: section.icon) }
                    }
                }
        }
#endif
    }

    @ViewBuilder private var content: some View {
        Group {
            switch section {
            case .overview: AIOverviewView(section: $section)
            case .providers: AIProvidersView()
            case .models: AIModelsView()
            case .credentials: AICredentialsView()
            case .inference: AIInferenceView()
            case .usage: AIUsageView()
            }
        }
        .environmentObject(state)
        .navigationTitle(section.title)
        .task { await state.loadAll() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { state.clearTransientSecrets() }
        }
        .onChange(of: section) { _, _ in state.clearTransientSecrets() }
        .alert("AI request failed", isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) {
            Button("OK") { state.error = nil }
        } message: { Text(state.error ?? "Unknown error") }
    }
}

public enum AISection: String, CaseIterable, Identifiable {
    case overview, providers, models, credentials, inference, usage
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var icon: String { switch self { case .overview: "square.grid.2x2"; case .providers: "network"; case .models: "cube"; case .credentials: "key"; case .inference: "sparkles"; case .usage: "chart.bar" } }
}
