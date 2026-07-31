import DesignSystem
import FeatureContracts
import SwiftUI
#if os(macOS)
import LayoutSystem
#endif

public struct ScratchFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.scratch")
    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.scratch.route.overview"),
            featureID: Self.featureID,
            title: "Scratch Feature",
            systemImage: "shippingbox",
            group: "Features",
            order: 100,
            access: .init(requiresSignIn: true, allowedRoles: ["admin"], deniedPresentation: .locked)
        ) { context in
            AnyView(ScratchFeatureView(settings: context.settings(Self.featureID)))
        })
    }
}

public struct ScratchFeatureView: View {
    private let settings: FeatureSettingsClient
    @State private var note = ""
    @State private var status = "Ready"
    #if os(macOS)
    @Environment(\.trailingInspectorController) private var inspectorController
    #endif

    public init(settings: FeatureSettingsClient) { self.settings = settings }

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "Scratch Feature",
                    subtitle: "A generated, registry-backed SwiftUI package",
                    systemImage: "shippingbox"
                )
                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        TextField("Namespaced note", text: $note)
                        HStack {
                            Button("Save") { Task { await save() } }.buttonStyle(.primary)
                            #if os(macOS)
                            if let inspectorController {
                                Button("Toggle Details") { inspectorController.toggle() }
                            }
                            #endif
                            Text(status).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Scratch Feature")
        .task { await load() }
        #if os(macOS)
        .trailingInspectorContent {
            ScratchTrailingInspector(note: $note, status: $status)
        }
        #endif
    }

    private func load() async {
        do { note = try await settings.value(String.self, forKey: "note") ?? "" }
        catch { status = "Couldn't load the note" }
    }

    private func save() async {
        do { try await settings.setValue(note, forKey: "note"); status = "Saved" }
        catch { status = "Couldn't save the note" }
    }
}

#if os(macOS)
private struct ScratchTrailingInspector: View {
    @Binding var note: String
    @Binding var status: String
    @Environment(\.trailingInspectorController) private var inspectorController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label("Scratch Details", systemImage: "shippingbox")
                    .font(Theme.Typography.headline)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Status")
                        .font(Theme.Typography.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(status)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Live Note")
                        .font(Theme.Typography.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(note.isEmpty ? "No note yet" : note)
                        .textSelection(.enabled)
                }

                Button("Hide Details") {
                    inspectorController?.hide()
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
