import SwiftUI
import FeatureContracts

/// About / Contact / Privacy static pages, ported from 11Q's
/// `Features/{About,Contact,Privacy}`. Three sign-in-free routes in one module.
public struct InfoPagesModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.info")
    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.info.route.about"),
            featureID: Self.featureID,
            title: "About",
            systemImage: "info.circle.fill",
            group: "Info",
            order: 91,
            access: .init(deniedPresentation: .locked)
        ) { _ in
            AnyView(NavigationStack { AboutView() })
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.info.route.contact"),
            featureID: Self.featureID,
            title: "Contact",
            systemImage: "envelope.open.fill",
            group: "Info",
            order: 92,
            access: .init(deniedPresentation: .locked)
        ) { _ in
            AnyView(NavigationStack { ContactView() })
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.info.route.privacy"),
            featureID: Self.featureID,
            title: "Privacy",
            systemImage: "lock.shield.fill",
            group: "Info",
            order: 93,
            access: .init(deniedPresentation: .locked)
        ) { _ in
            AnyView(NavigationStack { PrivacyView() })
        })
    }
}
