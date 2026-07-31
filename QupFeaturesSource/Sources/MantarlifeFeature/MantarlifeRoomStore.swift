import Foundation
import SwiftUI

/// Shared grow-room state for Overview / Environment / Climate / Timers / Device detail.
@MainActor
final class MantarlifeRoomStore: ObservableObject {
    @Published var settings: CoolkitRoomSettings?
    @Published var bindings: [CoolkitDeviceBinding] = []
    @Published var loops: [CoolkitServerLoop] = []
    @Published var devices: [CoolkitLiveDevice] = []
    @Published var families: [CoolkitFamily] = []
    @Published var samples: [CoolkitThSample] = []
    @Published var isBusy = false
    @Published var isNotLinked = false
    @Published var message: String?
    @Published var error: String?

    /// Last power snapshot keyed by device id (display strings).
    @Published var powerByDevice: [String: CoolkitPowerSnapshot] = [:]
    @Published var historyByDevice: [String: [CoolkitHistoryItem]] = [:]
    @Published var settingsByDevice: [String: CoolkitDeviceSettingsResponse] = [:]

    private let api = MantarlifeCoolkitAPI()

    struct CoolkitPowerSnapshot: Equatable {
        var watts: String
        var volts: String
        var amps: String
        var summary: String { "W \(watts) · V \(volts) · A \(amps)" }
    }

    func binding(role: String) -> CoolkitDeviceBinding? {
        bindings.first { $0.role == role }
    }

    func role(for deviceId: String) -> String? {
        bindings.first { $0.deviceId == deviceId }?.role
    }

    func role(for device: CoolkitLiveDevice) -> String {
        if let r = role(for: device.deviceId) { return r }
        let n = device.name.lowercased()
        if n.contains("petek") || n.contains("heat") { return "petek" }
        if n.contains("fan") { return "fan" }
        if n.contains("ultrason") { return "ultrasonik" }
        if n.contains("sisleme") || n.contains("mist") { return "sisleme" }
        return "other"
    }

    /// Fan → Petek → Sisleme → Ultrasonik → other
    var sortedDevices: [CoolkitLiveDevice] {
        let order = ["fan": 0, "petek": 1, "sisleme": 2, "ultrasonik": 3]
        return devices.sorted { a, b in
            let ra = order[role(for: a)] ?? 9
            let rb = order[role(for: b)] ?? 9
            if ra != rb { return ra < rb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func deviceId(role: String) -> String? {
        if let id = binding(role: role)?.deviceId, !id.isEmpty { return id }
        return devices.first { self.role(for: $0) == role }?.deviceId
    }

    func clearFlash() {
        error = nil
        message = nil
    }

    func load(accessToken: String) async {
        isBusy = true
        error = nil
        isNotLinked = false
        defer { isBusy = false }
        do {
            let room = try await api.getRoom(accessToken: accessToken)
            settings = room.settings
            bindings = room.bindings ?? []
            loops = room.loops ?? []

            var queryFamily = room.settings?.familyId
            if let fams = try? await api.listFamilies(accessToken: accessToken) {
                families = fams.families
                if queryFamily == nil {
                    queryFamily = fams.families.first(where: {
                        $0.name.localizedCaseInsensitiveContains("mantar")
                    })?.id ?? fams.families.first?.id
                }
            }
            let list = try await api.listDevices(accessToken: accessToken, familyId: queryFamily)
            devices = list.devices
        } catch let err as MantarlifeAPIError {
            if case .notLinked = err {
                isNotLinked = true
            }
            error = err.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func seedAndReconcile(accessToken: String) async {
        isBusy = true
        error = nil
        message = nil
        defer { isBusy = false }
        do {
            _ = try await api.seedRoom(accessToken: accessToken)
            let r = try await api.reconcileRoom(accessToken: accessToken)
            message = "Eşleştirme: \(r.matched ?? 0) binding"
            await load(accessToken: accessToken)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectFamily(accessToken: String, familyId: String, homeName: String?) async {
        do {
            _ = try await api.updateRoomSettings(
                accessToken: accessToken,
                familyId: familyId,
                homeName: homeName
            )
            await load(accessToken: accessToken)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func runScene(accessToken: String, name: String) async {
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            _ = try await api.runScene(accessToken: accessToken, name: name)
            message = "Sahne: \(name)"
            await load(accessToken: accessToken)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setSwitch(accessToken: String, deviceId: String, on: Bool) async {
        do {
            try await api.setSwitch(accessToken: accessToken, deviceId: deviceId, on: on)
            await load(accessToken: accessToken)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setOutlet(accessToken: String, deviceId: String, outlet: Int, on: Bool) async {
        do {
            try await api.setOutlet(accessToken: accessToken, deviceId: deviceId, outlet: outlet, on: on)
            await load(accessToken: accessToken)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyThermostat(
        accessToken: String,
        deviceId: String,
        mode: String = "temperature",
        high: Double,
        low: Double,
        fanCool: Bool = false
    ) async {
        do {
            if fanCool {
                _ = try await api.setThermostat(
                    accessToken: accessToken,
                    deviceId: deviceId,
                    mode: mode,
                    high: high,
                    low: low,
                    highSwitch: "on",
                    lowSwitch: "off"
                )
            } else {
                _ = try await api.setThermostat(
                    accessToken: accessToken,
                    deviceId: deviceId,
                    mode: mode,
                    high: high,
                    low: low
                )
            }
            message = "Termostat \(low)–\(high) uygulandı"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPower(accessToken: String, deviceId: String) async {
        do {
            let p = try await api.getPower(accessToken: accessToken, deviceId: deviceId, activate: true)
            powerByDevice[deviceId] = CoolkitPowerSnapshot(
                watts: p.powerW?.display ?? "—",
                volts: p.voltageV?.display ?? "—",
                amps: p.currentA?.display ?? "—"
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSettings(accessToken: String, deviceId: String) async {
        do {
            settingsByDevice[deviceId] = try await api.getDeviceSettings(
                accessToken: accessToken,
                deviceId: deviceId
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func saveSettings(
        accessToken: String,
        deviceId: String,
        startup: String?,
        pulse: String?,
        pulseWidthMs: Int?,
        sledOnline: String?
    ) async {
        do {
            let r = try await api.setDeviceSettings(
                accessToken: accessToken,
                deviceId: deviceId,
                pulse: pulse,
                pulseWidthMs: pulseWidthMs,
                startup: startup,
                sledOnline: sledOnline
            )
            settingsByDevice[deviceId] = r
            message = "Ayarlar kaydedildi"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadHistory(accessToken: String, deviceId: String) async {
        do {
            let h = try await api.getHistory(accessToken: accessToken, deviceId: deviceId, num: 30)
            historyByDevice[deviceId] = h.histories
        } catch {
            // Standard Role may deny — soft fail
            historyByDevice[deviceId] = []
            if error is MantarlifeAPIError {
                // keep quiet for history
            }
        }
    }

    func setCountdown(
        accessToken: String,
        deviceId: String,
        minutes: Int,
        switchOn: Bool,
        outlet: Int?
    ) async {
        do {
            _ = try await api.setCountdownTimer(
                accessToken: accessToken,
                deviceId: deviceId,
                minutes: minutes,
                switchState: switchOn ? "on" : "off",
                outlet: outlet,
                keepExisting: true
            )
            message = "Geri sayım \(minutes) dk"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setLoopEnabled(accessToken: String, loopId: Int, enabled: Bool) async {
        do {
            _ = try await api.setServerLoopEnabled(accessToken: accessToken, loopId: loopId, enabled: enabled)
            loops = (try? await api.listServerLoops(accessToken: accessToken).loops) ?? loops
        } catch {
            self.error = error.localizedDescription
        }
    }

    func pushNativeLoop(accessToken: String, loop: CoolkitServerLoop) async {
        let on = loop.onMinutes ?? 5
        let off = loop.offMinutes ?? 15
        do {
            _ = try await api.setLoopTimer(
                accessToken: accessToken,
                deviceId: loop.deviceId,
                onMinutes: on,
                offMinutes: off,
                outlet: loop.outlet,
                keepExisting: true
            )
            message = "Native döngü cihaza yazıldı"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSamples(accessToken: String, deviceId: String?) async {
        do {
            samples = try await api.getSamples(accessToken: accessToken, deviceId: deviceId, limit: 96).samples
        } catch {
            // optional
        }
    }

    func displayName(for device: CoolkitLiveDevice) -> String {
        let r = role(for: device)
        switch r {
        case "fan": return "Fan"
        case "petek": return "Petek"
        case "sisleme": return "Sisleme"
        case "ultrasonik": return "Ultrasonik"
        default: return device.name.isEmpty ? device.deviceId : device.name
        }
    }
}
