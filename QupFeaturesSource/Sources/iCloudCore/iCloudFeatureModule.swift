import DesignSystem
import FeatureContracts
import SwiftUI

public struct iCloudFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.icloud")
    
    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        for (index, section) in iCloudSection.allCases.enumerated() {
            let routeComponent = section == .photos ? "overview" : section.rawValue
            try registry.register(route: FeatureRouteContribution(
                id: FeatureRouteID("tech.qline.icloud.route.\(routeComponent)"),
                featureID: Self.featureID,
                title: section.title,
                systemImage: section.systemImage,
                group: "Features",
                order: 90 + index,
                access: .init(deniedPresentation: .locked)
            ) { _ in
                AnyView(iCloudFeatureView(initialSection: section))
            })
        }
    }
}
