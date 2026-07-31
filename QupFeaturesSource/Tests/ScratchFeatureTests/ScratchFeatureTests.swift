import FeatureContracts
import ScratchFeature
import Testing
#if os(macOS)
import LayoutSystem
import SwiftUI
#endif

@Suite("Scratch feature")
struct ScratchFeatureTests {
    @Test @MainActor func usesStablePackageNamespace() {
        #expect(ScratchFeatureModule.featureID.rawValue == "tech.qline.scratch")
        #expect(FeatureIdentifierValidation.isReverseDNS(ScratchFeatureModule.featureID.rawValue))
    }
}

#if os(macOS)
@MainActor
private final class ScratchInspectorCoordinator {
    private let controller: TrailingInspectorController
    private let registrationID = TrailingInspectorRegistrationID()

    init(controller: TrailingInspectorController) {
        self.controller = controller
    }

    func install(note: Binding<String>) {
        controller.register(registrationID) {
            Text(note.wrappedValue)
        }
    }

    func toggle() {
        controller.toggle()
    }

    func uninstall() {
        controller.unregister(registrationID)
    }
}

extension ScratchFeatureTests {
    @Test @MainActor func supportsClassOwnedInspectorRegistrationAndCleanup() {
        let controller = TrailingInspectorController()
        let note = Binding.constant("Coordinator-owned content")
        let coordinator = ScratchInspectorCoordinator(controller: controller)

        coordinator.install(note: note)
        #expect(controller.activeContent != nil)
        #expect(controller.isPresented == false)

        coordinator.toggle()
        #expect(controller.isPresented)

        coordinator.uninstall()
        #expect(controller.activeContent == nil)
    }
}
#endif
