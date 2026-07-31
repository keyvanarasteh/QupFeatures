import DesignSystem
import FeatureContracts
import Networking
import QlineAuth
import SwiftUI

public struct DynamicPagesFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.dynamic-pages")

    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.dynamic-pages.route.overview"),
            featureID: Self.featureID,
            title: "Dynamic Pages",
            systemImage: "doc.richtext",
            group: "Features",
            order: 112,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { context in
            AnyView(DynamicPagesRootView(client: context.qlineClient))
        })
    }
}
