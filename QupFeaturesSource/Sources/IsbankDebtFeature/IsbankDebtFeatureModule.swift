import FeatureContracts
import SwiftUI

/// Gerçek Borç Hesaplama — the İş Bankası enforcement-file calculator.
///
/// One route, no sign-in requirement: the figures live in the view, so the page
/// is useful offline and before the session resolves.
public struct IsbankDebtFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.isbank.debt")

    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.isbank.debt.route.calculator"),
            featureID: Self.featureID,
            title: "Gerçek Borç",
            systemImage: "banknote",
            group: "Hukuk",
            order: 95,
            access: .init(deniedPresentation: .locked)
        ) { _ in
            AnyView(NavigationStack { DebtCalculatorView() })
        })
    }
}
