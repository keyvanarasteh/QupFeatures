import DesignSystem
import Foundation
import QlineAuth
import SwiftUI

// MARK: - Environment

public struct MantarlifeEnvironmentView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.cupertinoColors) private var colors
    @StateObject private var store = MantarlifeRoomStore()
    @StateObject private var live = CoolkitLiveSession()
    @State private var petekHigh = "25"
    @State private var petekLow = "22"

    public init() {}

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "Environment",
                    subtitle: "Canlı kontrol · feed \(live.mode.rawValue)",
                    systemImage: "thermometer.medium"
                )

                toolbar
                banners

                if store.isNotLinked {
                    MLLinkCoolKitCard()
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Canlı TH").font(Theme.Typography.headline)
                        MLClimateReadout(
                            temperature: live.lastTemperature,
                            humidity: live.lastHumidity
                        )
                        Text(liveMeta)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.mutedFg)
                    }
                }

                if !store.samples.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Sıcaklık geçmişi").font(Theme.Typography.headline)
                            MLSparklineChart(samples: store.samples)
                        }
                    }
                }

                MLSceneBar(isBusy: store.isBusy) { name in
                    Task {
                        guard let t = try? await auth.requireAccessToken() else { return }
                        await store.runScene(accessToken: t, name: name)
                    }
                }

                MLThermostatBandEditor(
                    title: "Petek bant (°C)",
                    high: $petekHigh,
                    low: $petekLow
                ) {
                    Task { await applyBand(role: "petek", high: petekHigh, low: petekLow, fanCool: false) }
                }

                ForEach(store.sortedDevices) { device in
                    NavigationLink {
                        MantarlifeDeviceDetailView(
                            deviceId: device.deviceId,
                            store: store
                        )
                    } label: {
                        MLDeviceCard(
                            title: store.displayName(for: device),
                            role: store.role(for: device),
                            device: device,
                            onTogglePower: { on in
                                Task {
                                    guard let t = try? await auth.requireAccessToken() else { return }
                                    await store.setSwitch(accessToken: t, deviceId: device.deviceId, on: on)
                                }
                            },
                            onToggleOutlet: { outlet, on in
                                Task {
                                    guard let t = try? await auth.requireAccessToken() else { return }
                                    await store.setOutlet(
                                        accessToken: t,
                                        deviceId: device.deviceId,
                                        outlet: outlet,
                                        on: on
                                    )
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                if store.devices.isEmpty && !store.isBusy && !store.isNotLinked {
                    CardView {
                        Text("Cihaz yok. Seed + reconcile deneyin veya family seçin.")
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(colors.mutedFg)
                    }
                    ForEach(MantarlifeCatalog.devices) { d in
                        CardView {
                            Text("\(d.nameTR) · \(d.model) · \(d.id)")
                                .font(Theme.Typography.caption.monospaced())
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Environment")
        .refreshable { await bootstrap() }
        .task { await bootstrap() }
        .onDisappear { live.stop() }
    }

    private var liveMeta: String {
        var s = "mod \(live.mode.rawValue)"
        if let u = live.lastUpdate {
            s += " · " + RelativeDateTimeFormatter().localizedString(for: u, relativeTo: Date())
        }
        return s
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Button {
                    Task { await bootstrap() }
                } label: {
                    if store.isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Yenile", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.secondary)
                .disabled(!auth.isLoggedIn || store.isBusy)

                Button("Seed + reconcile") {
                    Task {
                        guard let t = try? await auth.requireAccessToken() else { return }
                        await store.seedAndReconcile(accessToken: t)
                        await bootstrapLive(token: t)
                    }
                }
                .buttonStyle(.secondary)
                .disabled(!auth.isLoggedIn || store.isBusy || store.isNotLinked)
            }

            MLFamilyPicker(
                families: store.families,
                currentName: store.settings?.homeName
            ) { f in
                Task {
                    guard let t = try? await auth.requireAccessToken() else { return }
                    await store.selectFamily(accessToken: t, familyId: f.id, homeName: f.name)
                }
            }
        }
    }

    @ViewBuilder
    private var banners: some View {
        if let error = store.error ?? live.lastError {
            MLStatusBanner(kind: .error, text: error)
        }
        if let message = store.message {
            MLStatusBanner(kind: .success, text: message)
        }
    }

    private func bootstrap() async {
        guard auth.isLoggedIn, let token = try? await auth.requireAccessToken() else { return }
        await store.load(accessToken: token)
        await bootstrapLive(token: token)
    }

    private func bootstrapLive(token: String) async {
        let petekId = store.deviceId(role: "petek")
        let thIds = ["petek", "fan"].compactMap { store.deviceId(role: $0) }
        await live.start(accessToken: token, preferredDeviceId: petekId, pollDeviceIds: thIds)
        await store.loadSamples(accessToken: token, deviceId: petekId)
    }

    private func applyBand(role: String, high: String, low: String, fanCool: Bool) async {
        guard let token = try? await auth.requireAccessToken() else { return }
        guard let id = store.deviceId(role: role),
              let h = Double(high), let l = Double(low) else {
            store.error = "Cihaz id veya sayısal bant eksik"
            return
        }
        await store.applyThermostat(
            accessToken: token,
            deviceId: id,
            high: h,
            low: l,
            fanCool: fanCool
        )
    }
}

// MARK: - Device detail

public struct MantarlifeDeviceDetailView: View {
    let deviceId: String
    @ObservedObject var store: MantarlifeRoomStore
    @EnvironmentObject private var auth: AuthService
    @Environment(\.cupertinoColors) private var colors

    @State private var high = "25"
    @State private var low = "22"
    @State private var startup = "off"
    @State private var pulse = "off"
    @State private var pulseWidth = "500"
    @State private var countdownMin = "15"
    @State private var countdownOn = false
    @State private var countdownOutlet = "0"

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let device = store.devices.first(where: { $0.deviceId == deviceId }) {
                    header(device)
                    switches(device)

                    if isTH(device) {
                        MLThermostatBandEditor(
                            title: store.role(for: device) == "fan" ? "Fan bant" : "Petek bant",
                            high: $high,
                            low: $low,
                            fanCoolHint: store.role(for: device) == "fan"
                        ) {
                            Task { await applyThermo(device) }
                        }
                    }

                    MLPowerTile(snapshot: store.powerByDevice[deviceId]) {
                        Task {
                            guard let t = try? await auth.requireAccessToken() else { return }
                            await store.loadPower(accessToken: t, deviceId: deviceId)
                        }
                    }

                    MLDeviceSettingsForm(
                        startup: $startup,
                        pulse: $pulse,
                        pulseWidth: $pulseWidth
                    ) {
                        Task { await saveSettings() }
                    }

                    MLCountdownForm(
                        minutes: $countdownMin,
                        switchOn: $countdownOn,
                        showOutlet: hasOutlets(device),
                        outlet: $countdownOutlet
                    ) {
                        Task { await applyCountdown(device) }
                    }

                    MLHistoryList(items: store.historyByDevice[deviceId] ?? [])
                } else {
                    Text("Cihaz listede yok — Environment’tan yenileyin.")
                        .foregroundStyle(colors.mutedFg)
                }

                if let error = store.error {
                    MLStatusBanner(kind: .error, text: error)
                }
                if let message = store.message {
                    MLStatusBanner(kind: .success, text: message)
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Cihaz")
        .task { await loadDetail() }
    }

    private func header(_ device: CoolkitLiveDevice) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(store.displayName(for: device)).font(Theme.Typography.title3)
                    MLRoleBadge(role: store.role(for: device))
                    Spacer()
                    Text(device.online == true ? "Online" : "Offline")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(device.online == true ? colors.success : colors.mutedFg)
                }
                Text(device.deviceId)
                    .font(Theme.Typography.caption.monospaced())
                    .foregroundStyle(colors.mutedFg)
                MLClimateReadout(
                    temperature: device.temperature?.doubleValue,
                    humidity: device.humidity?.doubleValue,
                    compact: true
                )
            }
        }
    }

    @ViewBuilder
    private func switches(_ device: CoolkitLiveDevice) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Kontrol").font(Theme.Typography.headline)
                if let channels = device.switches, !channels.isEmpty {
                    ForEach(Array(channels.enumerated()), id: \.offset) { _, ch in
                        MLOutletRow(
                            outlet: ch.outlet ?? 0,
                            isOn: ch.isOn,
                            label: nil
                        ) { on in
                            Task {
                                guard let t = try? await auth.requireAccessToken() else { return }
                                await store.setOutlet(
                                    accessToken: t,
                                    deviceId: deviceId,
                                    outlet: ch.outlet ?? 0,
                                    on: on
                                )
                            }
                        }
                    }
                } else {
                    Toggle("Güç", isOn: Binding(
                        get: { device.switch?.lowercased() == "on" },
                        set: { on in
                            Task {
                                guard let t = try? await auth.requireAccessToken() else { return }
                                await store.setSwitch(accessToken: t, deviceId: deviceId, on: on)
                            }
                        }
                    ))
                }
            }
        }
    }

    private func isTH(_ d: CoolkitLiveDevice) -> Bool {
        let r = store.role(for: d)
        return r == "fan" || r == "petek"
    }

    private func hasOutlets(_ d: CoolkitLiveDevice) -> Bool {
        !(d.switches ?? []).isEmpty
    }

    private func loadDetail() async {
        guard let t = try? await auth.requireAccessToken() else { return }
        await store.loadPower(accessToken: t, deviceId: deviceId)
        await store.loadSettings(accessToken: t, deviceId: deviceId)
        await store.loadHistory(accessToken: t, deviceId: deviceId)
        if let s = store.settingsByDevice[deviceId] {
            startup = s.startup?.stringValue ?? "off"
            pulse = s.pulse?.stringValue ?? "off"
            if let w = s.pulseWidth?.doubleValue {
                pulseWidth = String(Int(w))
            }
        }
    }

    private func applyThermo(_ device: CoolkitLiveDevice) async {
        guard let t = try? await auth.requireAccessToken(),
              let h = Double(high), let l = Double(low) else { return }
        await store.applyThermostat(
            accessToken: t,
            deviceId: deviceId,
            high: h,
            low: l,
            fanCool: store.role(for: device) == "fan"
        )
    }

    private func saveSettings() async {
        guard let t = try? await auth.requireAccessToken() else { return }
        let w = Int(pulseWidth)
        await store.saveSettings(
            accessToken: t,
            deviceId: deviceId,
            startup: startup,
            pulse: pulse,
            pulseWidthMs: w,
            sledOnline: nil
        )
    }

    private func applyCountdown(_ device: CoolkitLiveDevice) async {
        guard let t = try? await auth.requireAccessToken(),
              let m = Int(countdownMin), m > 0 else { return }
        let outlet: Int? = hasOutlets(device) ? Int(countdownOutlet) : nil
        await store.setCountdown(
            accessToken: t,
            deviceId: deviceId,
            minutes: m,
            switchOn: countdownOn,
            outlet: outlet
        )
    }
}

// MARK: - Climate

public struct MantarlifeClimateView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.cupertinoColors) private var colors
    @StateObject private var store = MantarlifeRoomStore()
    @StateObject private var live = CoolkitLiveSession()
    @State private var petekHigh = "25"
    @State private var petekLow = "22"
    @State private var fanHigh = "28"
    @State private var fanLow = "26"

    public init() {}

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "Climate",
                    subtitle: "Canlı TH · Petek & Fan bantları",
                    systemImage: "thermometer.sun"
                )

                if let error = store.error ?? live.lastError {
                    MLStatusBanner(kind: .error, text: error)
                }
                if let message = store.message {
                    MLStatusBanner(kind: .success, text: message)
                }

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        MLClimateReadout(
                            temperature: live.lastTemperature,
                            humidity: live.lastHumidity
                        )
                        Text("feed \(live.mode.rawValue)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(colors.mutedFg)
                    }
                }

                if !store.samples.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Grafik").font(Theme.Typography.headline)
                            MLSparklineChart(samples: store.samples, height: 100)
                        }
                    }
                }

                MLThermostatBandEditor(title: "Petek (ısı)", high: $petekHigh, low: $petekLow) {
                    Task { await apply("petek", petekHigh, petekLow, false) }
                }
                MLThermostatBandEditor(
                    title: "Fan (soğutma)",
                    high: $fanHigh,
                    low: $fanLow,
                    fanCoolHint: true
                ) {
                    Task { await apply("fan", fanHigh, fanLow, true) }
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Climate")
        .refreshable { await boot() }
        .task { await boot() }
        .onDisappear { live.stop() }
    }

    private func boot() async {
        guard let t = try? await auth.requireAccessToken() else { return }
        await store.load(accessToken: t)
        let petek = store.deviceId(role: "petek")
        await live.start(
            accessToken: t,
            preferredDeviceId: petek,
            pollDeviceIds: ["petek", "fan"].compactMap { store.deviceId(role: $0) }
        )
        await store.loadSamples(accessToken: t, deviceId: petek)
    }

    private func apply(_ role: String, _ high: String, _ low: String, _ cool: Bool) async {
        guard let t = try? await auth.requireAccessToken(),
              let id = store.deviceId(role: role),
              let h = Double(high), let l = Double(low) else {
            store.error = "Cihaz veya bant değeri eksik"
            return
        }
        await store.applyThermostat(accessToken: t, deviceId: id, high: h, low: l, fanCool: cool)
    }
}

// MARK: - Timers

public struct MantarlifeTimersView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.cupertinoColors) private var colors
    @StateObject private var store = MantarlifeRoomStore()

    public init() {}

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "Loop Timers",
                    subtitle: "Sunucu döngüleri · Hostinger cron: process-coolkit-loops.php",
                    systemImage: "timer"
                )

                HStack {
                    Button("Yenile") {
                        Task {
                            guard let t = try? await auth.requireAccessToken() else { return }
                            await store.load(accessToken: t)
                        }
                    }
                    .buttonStyle(.secondary)
                    Button("Seed defaults") {
                        Task {
                            guard let t = try? await auth.requireAccessToken() else { return }
                            await store.seedAndReconcile(accessToken: t)
                        }
                    }
                    .buttonStyle(.secondary)
                }

                if let error = store.error {
                    MLStatusBanner(kind: .error, text: error)
                }
                if let message = store.message {
                    MLStatusBanner(kind: .success, text: message)
                }

                if store.loops.isEmpty {
                    ForEach(MantarlifeCatalog.loopTimers) { timer in
                        CardView {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text(timer.target).font(Theme.Typography.headline)
                                Text(timer.cycleSummary).font(Theme.Typography.title3)
                                Text("Katalog — seed ile sunucu döngüsü oluşturun")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(colors.mutedFg)
                            }
                        }
                    }
                } else {
                    ForEach(store.loops) { loop in
                        MLLoopRow(
                            loop: loop,
                            onEnable: { en in
                                Task {
                                    guard let t = try? await auth.requireAccessToken() else { return }
                                    await store.setLoopEnabled(accessToken: t, loopId: loop.id, enabled: en)
                                }
                            },
                            onNative: {
                                Task {
                                    guard let t = try? await auth.requireAccessToken() else { return }
                                    await store.pushNativeLoop(accessToken: t, loop: loop)
                                }
                            }
                        )
                    }
                }

                CardView {
                    Text("Birincil 5/15 ve 3/15 core-api worker ile çalışır. Native timer yedek.")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(colors.mutedFg)
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("Loop Timers")
        .refreshable {
            guard let t = try? await auth.requireAccessToken() else { return }
            await store.load(accessToken: t)
        }
        .task {
            guard let t = try? await auth.requireAccessToken() else { return }
            await store.load(accessToken: t)
        }
    }
}

// MARK: - DIY LAN (farm Wi‑Fi only)

public struct MantarlifeDiyView: View {
    @Environment(\.cupertinoColors) private var colors
    @State private var host = "192.168.1.50"
    @State private var deviceId = "100296b50f"
    @State private var result = ""
    @State private var isBusy = false

    private let diy = CoolkitDiyAPI()

    public init() {}

    public var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader(
                    "DIY LAN",
                    subtitle: "Yalnızca çiftlik Wi‑Fi · Hostinger’dan çalışmaz",
                    systemImage: "wifi.router"
                )

                CardView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Cihaz DIY Mode’da olmalı; eWeLink bulut o birim için genelde kapanır.")
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(colors.mutedFg)
                        TextField("Host IP", text: $host)
                            .textFieldStyle(.roundedBorder)
                        TextField("Device ID", text: $deviceId)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                        HStack {
                            Button("Info") { Task { await runInfo() } }
                                .buttonStyle(.secondary)
                                .disabled(isBusy)
                            Button("Aç") { Task { await runSwitch(true) } }
                                .buttonStyle(.primary)
                                .disabled(isBusy)
                            Button("Kapat") { Task { await runSwitch(false) } }
                                .buttonStyle(.secondary)
                                .disabled(isBusy)
                        }
                        if !result.isEmpty {
                            Text(result)
                                .font(Theme.Typography.caption.monospaced())
                                .foregroundStyle(colors.mutedFg)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("DIY LAN")
    }

    private func runInfo() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let r = try await diy.info(host: host, deviceId: deviceId)
            result = String(describing: r)
        } catch {
            result = error.localizedDescription
        }
    }

    private func runSwitch(_ on: Bool) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let r = try await diy.setSwitch(host: host, deviceId: deviceId, on: on)
            result = String(describing: r)
        } catch {
            result = error.localizedDescription
        }
    }
}
