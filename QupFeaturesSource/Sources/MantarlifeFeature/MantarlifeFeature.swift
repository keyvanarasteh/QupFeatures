import Combine
import DesignSystem
import FeatureContracts
import Foundation
import QlineAuth
import SwiftUI

// MARK: - Module

public struct MantarlifeFeatureModule: FeatureModule {
    public static let featureID = FeatureID("tech.qline.mantarlife")
    public init() {}

    @MainActor
    public func register(in registry: FeatureRegistry, context: FeatureContext) throws {
        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.overview"),
            featureID: Self.featureID,
            title: "MantarLife",
            systemImage: "leaf.fill",
            group: "Features",
            order: 85,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { context in
            AnyView(MantarlifeOverviewView(settings: context.settings(Self.featureID)))
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.environment"),
            featureID: Self.featureID,
            title: "Environment",
            systemImage: "thermometer.medium",
            group: "Features",
            order: 86,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { _ in
            AnyView(MantarlifeEnvironmentView())
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.climate"),
            featureID: Self.featureID,
            title: "Climate",
            systemImage: "thermometer.sun.fill",
            group: "Features",
            order: 87,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { _ in
            AnyView(MantarlifeClimateView())
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.timers"),
            featureID: Self.featureID,
            title: "Loop Timers",
            systemImage: "timer",
            group: "Features",
            order: 88,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { _ in
            AnyView(MantarlifeTimersView())
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.diy"),
            featureID: Self.featureID,
            title: "DIY LAN",
            systemImage: "wifi.router",
            group: "Features",
            order: 89,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { _ in
            AnyView(MantarlifeDiyView())
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.research"),
            featureID: Self.featureID,
            title: "Research",
            systemImage: "book.pages",
            group: "Features",
            order: 90,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { context in
            AnyView(MantarlifeResearchView(settings: context.settings(Self.featureID)))
        })

        try registry.register(route: FeatureRouteContribution(
            id: FeatureRouteID("tech.qline.mantarlife.route.api"),
            featureID: Self.featureID,
            title: "eWeLink API",
            systemImage: "network",
            group: "Features",
            order: 91,
            access: .init(requiresSignIn: true, deniedPresentation: .locked)
        ) { _ in
            AnyView(MantarlifeAPIGuideView())
        })
    }
}

// MARK: - Notes store

@MainActor
public final class MantarlifeStore: ObservableObject {
    public enum State: Equatable { case loading, empty, loaded, failed }

    @Published public var notes = ""
    @Published public private(set) var state: State = .loading
    private let settings: FeatureSettingsClient

    public init(settings: FeatureSettingsClient) {
        self.settings = settings
    }

    public func load() async {
        state = .loading
        do {
            notes = try await settings.value(String.self, forKey: "notes") ?? ""
            state = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .loaded
        } catch {
            state = .failed
        }
    }

    public func save() async {
        do {
            try await settings.setValue(notes, forKey: "notes")
            state = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .empty : .loaded
        } catch {
            state = .failed
        }
    }
}

// MARK: - Overview (live)

public struct MantarlifeOverviewView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.cupertinoColors) private var colors
    @StateObject private var notesStore: MantarlifeStore
    @StateObject private var room = MantarlifeRoomStore()
    @StateObject private var live = CoolkitLiveSession()

    public init(settings: FeatureSettingsClient) {
        _notesStore = StateObject(wrappedValue: MantarlifeStore(settings: settings))
    }

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "MantarLife",
                    subtitle: "Grow-room · home “\(MantarlifeRoom.homeName)”",
                    systemImage: "leaf.fill"
                )

                if room.isNotLinked {
                    MLLinkCoolKitCard()
                }

                if let error = room.error ?? live.lastError {
                    MLStatusBanner(kind: .error, text: error)
                }
                if let message = room.message {
                    MLStatusBanner(kind: .success, text: message)
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Canlı iklim").font(Theme.Typography.headline)
                        MLClimateReadout(
                            temperature: live.lastTemperature,
                            humidity: live.lastHumidity
                        )
                        Text("feed \(live.mode.rawValue) · cihaz \(room.devices.count) · döngü \(room.loops.filter(\.enabled).count) açık")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.mutedFg)
                        if let email = auth.user?.email {
                            Text(email)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(colors.mutedFg)
                        }
                    }
                }

                HStack(spacing: Theme.Spacing.md) {
                    MLStatTile(
                        title: "Cihaz",
                        value: "\(room.devices.isEmpty ? MantarlifeCatalog.devices.count : room.devices.count)",
                        icon: "sensor.tag.radiowaves.forward"
                    )
                    MLStatTile(
                        title: "Döngü",
                        value: "\(room.loops.filter(\.enabled).count)",
                        icon: "timer"
                    )
                }

                MLSceneBar(isBusy: room.isBusy) { name in
                    Task {
                        guard let t = try? await auth.requireAccessToken() else { return }
                        await room.runScene(accessToken: t, name: name)
                    }
                }

                HStack {
                    Button("Seed + reconcile") {
                        Task {
                            guard let t = try? await auth.requireAccessToken() else { return }
                            await room.seedAndReconcile(accessToken: t)
                        }
                    }
                    .buttonStyle(.secondary)
                    .disabled(!auth.isLoggedIn || room.isBusy || room.isNotLinked)

                    Button("Yenile") {
                        Task { await boot() }
                    }
                    .buttonStyle(.ghost)
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Roller").font(Theme.Typography.headline)
                        ForEach(MantarlifeCatalog.devices) { device in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: device.kind.systemImage)
                                    .foregroundStyle(colors.primary)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(device.nameTR) · \(device.model)")
                                        .font(Theme.Typography.body)
                                    Text(device.role)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(colors.mutedFg)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                notesStatus
                Spacer(minLength: 0)
            }
        }
        .navigationTitle("MantarLife")
        .refreshable { await boot() }
        .task {
            await notesStore.load()
            await boot()
        }
        .onDisappear { live.stop() }
    }

    private func boot() async {
        guard auth.isLoggedIn, let token = try? await auth.requireAccessToken() else { return }
        await room.load(accessToken: token)
        let petek = room.deviceId(role: "petek")
        await live.start(
            accessToken: token,
            preferredDeviceId: petek,
            pollDeviceIds: ["petek", "fan"].compactMap { room.deviceId(role: $0) }
        )
    }

    @ViewBuilder
    private var notesStatus: some View {
        switch notesStore.state {
        case .loading:
            ProgressView("Notlar…")
        case .empty:
            Label("Araştırma notu yok — Research’e gidin.", systemImage: "tray")
                .font(Theme.Typography.footnote)
                .foregroundStyle(colors.mutedFg)
        case .loaded:
            Label("Araştırma notları kayıtlı.", systemImage: "checkmark.circle.fill")
                .font(Theme.Typography.footnote)
                .foregroundStyle(.green)
        case .failed:
            Label("Notlar yüklenemedi.", systemImage: "exclamationmark.triangle")
                .font(Theme.Typography.footnote)
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Research

public struct MantarlifeResearchView: View {
    @Environment(\.cupertinoColors) private var colors
    @StateObject private var store: MantarlifeStore

    public init(settings: FeatureSettingsClient) {
        _store = StateObject(wrappedValue: MantarlifeStore(settings: settings))
    }

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "Research",
                    subtitle: "Lab notes — medicinal fungi R&D",
                    systemImage: "book.pages"
                )

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Workspace notes").font(Theme.Typography.headline)
                        TextEditor(text: $store.notes)
                            .frame(minHeight: 180)
                            .padding(Theme.Spacing.sm)
                            .background(
                                colors.surface.opacity(0.6),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            )
                        HStack {
                            Button("Save") { Task { await store.save() } }
                                .buttonStyle(.primary)
                            statusLabel
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("İklim yığını").font(Theme.Typography.headline)
                        bullet("THR320D Petek — ısı + TH")
                        bullet("THR320D Fan — havalandırma")
                        bullet("DUALR3 Sisleme — çift kanal")
                        bullet("DUALR3 Ultrasonik — 5/15 döngü")
                    }
                }

                NavigationLink {
                    MantarlifeLabView()
                } label: {
                    CardView {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "move.3d")
                                .font(.title2)
                                .foregroundStyle(colors.primary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("3D dijital ikiz")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(colors.fg)
                                Text("Raf, HVAC, IoT sahnesi — masaüstü & mobil sürüm")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(colors.mutedFg)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(colors.mutedFg)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Research")
        .task { await store.load() }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 6)
                .foregroundStyle(colors.primary)
            Text(text).font(Theme.Typography.footnote)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch store.state {
        case .loading: ProgressView().controlSize(.small)
        case .empty: Text("Empty").font(Theme.Typography.caption).foregroundStyle(colors.mutedFg)
        case .loaded: Text("Saved").font(Theme.Typography.caption).foregroundStyle(.green)
        case .failed: Text("Error").font(Theme.Typography.caption).foregroundStyle(.orange)
        }
    }
}

// MARK: - API guide

public struct MantarlifeAPIGuideView: View {
    @Environment(\.cupertinoColors) private var colors

    public init() {}

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "eWeLink / CoolKit API",
                    subtitle: "Hostinger shared PHP → CoolKit cloud · DIY only on farm LAN",
                    systemImage: "network"
                )

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Önce hesap bağla").font(Theme.Typography.headline)
                        Text("Profile → CoolKit / eWeLink. App secret sadece core-api .env.")
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(colors.mutedFg)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Proxy (uygulama)").font(Theme.Typography.headline)
                        mono("GET|POST /api/coolkit/devices|status|switches|…")
                        mono("GET|PUT  /api/coolkit/room")
                        mono("POST     /api/coolkit/room/seed|reconcile|scenes/{name}")
                        mono("GET|POST /api/coolkit/room/loops|samples")
                        Text("Döngüler: Hostinger cron → process-coolkit-loops.php")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.mutedFg)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("UI routes").font(Theme.Typography.headline)
                        bullet("Environment — cihaz + sahneler")
                        bullet("Climate — TH + bantlar")
                        bullet("Loop Timers — sunucu 5/15")
                        bullet("DIY LAN — yalnızca çiftlik Wi‑Fi")
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("eWeLink API")
    }

    private func mono(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.caption.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 6)
                .foregroundStyle(colors.primary)
            Text(text).font(Theme.Typography.footnote)
        }
    }
}
