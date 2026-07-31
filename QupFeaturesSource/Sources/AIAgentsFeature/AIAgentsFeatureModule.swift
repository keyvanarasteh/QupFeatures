import DesignSystem
import FeatureContracts
import SwiftUI

public struct AIAgentsFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.aiagents")
    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.aiagents.route.overview"),
            featureID: Self.featureID,
            title: "AI Agents",
            systemImage: "cpu",
            group: "Features",
            order: 95,
            access: .init(deniedPresentation: .hidden)
        ) { context in
            AnyView(AIAgentsListView(settings: context.settings(Self.featureID), apiClient: context.qlineClient))
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.aiagents.route.setup"),
            featureID: Self.featureID,
            title: "Agent CLI Setup",
            systemImage: "terminal",
            group: "Features",
            order: 96,
            access: .init(deniedPresentation: .hidden)
        ) { context in
            AnyView(AgentsSetupView(settings: context.settings(Self.featureID)))
        })
    }
}
