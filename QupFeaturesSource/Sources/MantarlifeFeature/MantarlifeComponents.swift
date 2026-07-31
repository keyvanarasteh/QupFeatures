import DesignSystem
import SwiftUI

// MARK: - Status

struct MLStatusBanner: View {
    enum Kind { case error, success, info }
    let kind: Kind
    let text: String
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        Label(text, systemImage: icon)
            .font(Theme.Typography.footnote)
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: String {
        switch kind {
        case .error: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var fg: Color {
        switch kind {
        case .error: return colors.warning
        case .success: return colors.success
        case .info: return colors.mutedFg
        }
    }
}

struct MLLinkCoolKitCard: View {
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("CoolKit bağlı değil", systemImage: "link.badge.plus")
                    .font(Theme.Typography.headline)
                Text("Profile → Connected Accounts → CoolKit / eWeLink veya IDS → CoolKit. Ardından Seed + reconcile.")
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(colors.mutedFg)
            }
        }
    }
}

// MARK: - Climate

struct MLClimateReadout: View {
    let temperature: Double?
    let humidity: Double?
    var compact: Bool = false
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            metric(
                "Sıcaklık",
                temperature.map { String(format: "%.1f°C", $0) } ?? "—",
                "thermometer"
            )
            metric(
                "Nem",
                humidity.map { String(format: "%.1f%%", $0) } ?? "—",
                "humidity"
            )
        }
    }

    private func metric(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
            Text(value)
                .font(compact ? Theme.Typography.title3 : Theme.Typography.title2)
        }
    }
}

struct MLSparklineChart: View {
    let samples: [CoolkitThSample]
    var height: CGFloat = 64
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        let temps = samples.compactMap(\.tempC).reversed()
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            GeometryReader { geo in
                Path { path in
                    guard let minT = temps.min(), let maxT = temps.max(), temps.count > 1 else { return }
                    let span = max(maxT - minT, 0.1)
                    for (i, t) in temps.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(temps.count - 1)
                        let y = geo.size.height * (1 - CGFloat((t - minT) / span))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(colors.primary, lineWidth: 2)
            }
            .frame(height: height)
            Text("\(samples.count) örnek")
                .font(Theme.Typography.caption)
                .foregroundStyle(colors.mutedFg)
        }
    }
}

// MARK: - Scenes / family

struct MLSceneBar: View {
    var isBusy: Bool
    var onScene: (String) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            scene("Gece nem", "night_humidify")
            scene("Hepsi kapalı", "all_off")
            scene("Gündüz fan", "day_vent")
        }
    }

    private func scene(_ title: String, _ name: String) -> some View {
        Button(title) { onScene(name) }
            .buttonStyle(.secondary)
            .disabled(isBusy)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct MLFamilyPicker: View {
    let families: [CoolkitFamily]
    let currentName: String?
    var onSelect: (CoolkitFamily) -> Void

    var body: some View {
        if families.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(families) { f in
                    Button(f.name.isEmpty ? f.id : f.name) { onSelect(f) }
                }
            } label: {
                Label(
                    "Ev: \(currentName ?? "MantarLife")",
                    systemImage: "house"
                )
                .font(Theme.Typography.footnote)
            }
        }
    }
}

struct MLRoleBadge: View {
    let role: String
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        Text(label)
            .font(Theme.Typography.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colors.primarySoft, in: Capsule())
    }

    private var label: String {
        switch role {
        case "fan": return "Fan"
        case "petek": return "Petek"
        case "sisleme": return "Sisleme"
        case "ultrasonik": return "Ultrasonik"
        default: return role
        }
    }
}

struct MLStatTile: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Image(systemName: icon).foregroundStyle(colors.primary)
                Text(value).font(Theme.Typography.title2)
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Device card (list)

struct MLDeviceCard: View {
    let title: String
    let role: String
    let device: CoolkitLiveDevice
    var onTogglePower: ((Bool) -> Void)?
    var onToggleOutlet: ((Int, Bool) -> Void)?

    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(title).font(Theme.Typography.headline)
                            MLRoleBadge(role: role)
                        }
                        Text([
                            device.productModel,
                            device.online == true ? "Online" : "Offline",
                            device.deviceId,
                        ].compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.Typography.caption.monospaced())
                        .foregroundStyle(colors.mutedFg)
                    }
                    Spacer()
                    Circle()
                        .fill(device.online == true ? colors.success : colors.mutedFg)
                        .frame(width: 10, height: 10)
                }

                HStack(spacing: Theme.Spacing.md) {
                    if let t = device.temperature?.display, t != "—" {
                        Label("\(t)°", systemImage: "thermometer")
                    }
                    if let h = device.humidity?.display, h != "—" {
                        Label("\(h)%RH", systemImage: "humidity")
                    }
                }
                .font(Theme.Typography.footnote)

                if let channels = device.switches, !channels.isEmpty {
                    ForEach(Array(channels.enumerated()), id: \.offset) { _, ch in
                        MLOutletRow(
                            outlet: ch.outlet ?? 0,
                            isOn: ch.isOn,
                            label: outletLabel(ch.outlet ?? 0),
                            onChange: { on in onToggleOutlet?(ch.outlet ?? 0, on) }
                        )
                    }
                } else if let onTogglePower {
                    HStack {
                        Text("Güç")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { device.switch?.lowercased() == "on" },
                            set: { onTogglePower($0) }
                        ))
                        .labelsHidden()
                    }
                }

                Text("Detay ›")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.primary)
            }
        }
    }

    private func outletLabel(_ outlet: Int) -> String {
        switch role {
        case "sisleme": return outlet == 0 ? "Sisleme 1" : "Sisleme 2"
        case "ultrasonik": return "Ultrasonik"
        default: return "Outlet \(outlet)"
        }
    }
}

struct MLOutletRow: View {
    let outlet: Int
    let isOn: Bool
    var label: String?
    var onChange: (Bool) -> Void

    var body: some View {
        HStack {
            Text(label ?? "Outlet \(outlet)")
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { onChange($0) }
            ))
            .labelsHidden()
        }
    }
}

// MARK: - Power / thermostat / settings / countdown / history / loop

struct MLPowerTile: View {
    let snapshot: MantarlifeRoomStore.CoolkitPowerSnapshot?
    var isLoading: Bool = false
    var onRefresh: () -> Void
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Tüketim").font(Theme.Typography.headline)
                    Spacer()
                    Button("Yenile") { onRefresh() }
                        .buttonStyle(.ghost)
                        .disabled(isLoading)
                }
                if let snapshot {
                    Text(snapshot.summary)
                        .font(Theme.Typography.title3.monospaced())
                } else {
                    Text("Henüz okunmadı — Yenile (uiActive)")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(colors.mutedFg)
                }
            }
        }
    }
}

struct MLThermostatBandEditor: View {
    let title: String
    @Binding var high: String
    @Binding var low: String
    var fanCoolHint: Bool = false
    var onApply: () -> Void

    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title).font(Theme.Typography.headline)
                if fanCoolHint {
                    Text("Fan: yüksekte aç / düşükte kapat")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.mutedFg)
                }
                HStack {
                    TextField("Üst", text: $high)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Alt", text: $low)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Button("Uygula") { onApply() }
                        .buttonStyle(.primary)
                }
            }
        }
    }
}

struct MLDeviceSettingsForm: View {
    @Binding var startup: String
    @Binding var pulse: String
    @Binding var pulseWidth: String
    var onSave: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Cihaz ayarları").font(Theme.Typography.headline)
                Picker("Açılış gücü", selection: $startup) {
                    Text("off").tag("off")
                    Text("on").tag("on")
                    Text("stay").tag("stay")
                }
                Picker("Inching (pulse)", selection: $pulse) {
                    Text("off").tag("off")
                    Text("on").tag("on")
                }
                TextField("Pulse ms (500…)", text: $pulseWidth)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Button("Kaydet") { onSave() }
                    .buttonStyle(.primary)
            }
        }
    }
}

struct MLCountdownForm: View {
    @Binding var minutes: String
    @Binding var switchOn: Bool
    var showOutlet: Bool = false
    @Binding var outlet: String
    var onApply: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Geri sayım").font(Theme.Typography.headline)
                HStack {
                    TextField("Dakika", text: $minutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Toggle(switchOn ? "Aç" : "Kapat", isOn: $switchOn)
                }
                if showOutlet {
                    TextField("Outlet", text: $outlet)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                Button("Kur") { onApply() }
                    .buttonStyle(.secondary)
            }
        }
    }
}

struct MLHistoryList: View {
    let items: [CoolkitHistoryItem]
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Kayıtlar").font(Theme.Typography.headline)
                if items.isEmpty {
                    Text("Kayıt yok veya API kısıtlı (Standard Role).")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(colors.mutedFg)
                } else {
                    ForEach(Array(items.prefix(20).enumerated()), id: \.offset) { _, item in
                        Text(row(item))
                            .font(Theme.Typography.caption.monospaced())
                            .foregroundStyle(colors.mutedFg)
                    }
                }
            }
        }
    }

    private func row(_ item: CoolkitHistoryItem) -> String {
        let t = item.opsTime?.display ?? "—"
        return "\(t)"
    }
}

struct MLLoopRow: View {
    let loop: CoolkitServerLoop
    var onEnable: (Bool) -> Void
    var onNative: () -> Void
    @Environment(\.cupertinoColors) private var colors

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text(loop.name).font(Theme.Typography.headline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { loop.enabled },
                        set: { onEnable($0) }
                    ))
                    .labelsHidden()
                }
                Text(loop.cycleSummary).font(Theme.Typography.title3)
                Text("device \(loop.deviceId)" + (loop.outlet.map { " · outlet \($0)" } ?? ""))
                    .font(Theme.Typography.caption.monospaced())
                    .foregroundStyle(colors.mutedFg)
                Text("faz \(loop.phase ?? "—") · tick \(loop.lastTickAt ?? "—")")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(colors.mutedFg)
                if let err = loop.lastError, !err.isEmpty {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(colors.warning)
                }
                Button("Cihaza native döngü yaz") { onNative() }
                    .buttonStyle(.ghost)
            }
        }
    }
}
