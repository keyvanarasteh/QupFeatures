import Testing
@testable import MantarlifeFeature
import FeatureContracts

@MainActor
@Test func featureIDIsStable() {
    #expect(MantarlifeFeatureModule.featureID == FeatureID("tech.qline.mantarlife"))
}

@MainActor
@Test func moduleCanBeConstructed() {
    _ = MantarlifeFeatureModule()
}

@Test func catalogMatchesEnvironmentDoc() {
    #expect(MantarlifeCatalog.devices.count == 4)
    #expect(MantarlifeCatalog.devices.contains(where: { $0.id == "100296b50f" }))
    #expect(MantarlifeCatalog.devices.contains(where: { $0.id == "100275a48c" }))
    #expect(MantarlifeCatalog.devices.contains(where: { $0.id == "100275a49e" }))
    #expect(MantarlifeCatalog.loopTimers.count == 2)
    #expect(MantarlifeCatalog.loopTimers[0].onMinutes == 5)
    #expect(MantarlifeCatalog.loopTimers[0].offMinutes == 15)
}

@Test func roomHomeNameIsMantarLife() {
    #expect(MantarlifeRoom.homeName == "MantarLife")
}

@Test func diyClientConstructs() {
    _ = CoolkitDiyAPI()
    _ = CoolkitDiyAPI(port: 8081)
}

@MainActor
@Test func roomStoreRoleOrderHelpers() {
    let store = MantarlifeRoomStore()
    #expect(store.binding(role: "fan") == nil)
    #expect(store.sortedDevices.isEmpty)
}

@MainActor
@Test func componentViewsConstruct() {
    _ = MLStatusBanner(kind: .info, text: "ok")
    _ = MLLinkCoolKitCard()
    _ = MLClimateReadout(temperature: 22.3, humidity: 90)
    _ = MLSparklineChart(samples: [])
    _ = MLSceneBar(isBusy: false, onScene: { _ in })
    _ = MLStatTile(title: "Cihaz", value: "4", icon: "leaf")
    _ = MLRoleBadge(role: "petek")
    _ = MantarlifeClimateView()
    _ = MantarlifeDiyView()
    _ = MantarlifeEnvironmentView()
    _ = MantarlifeTimersView()
}
