import Foundation
import QlineAuth

// MARK: - Errors

enum MantarlifeAPIError: LocalizedError, Sendable {
    case api(message: String, statusCode: Int?)
    case notLinked
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .api(let message, let statusCode):
            if let statusCode { return "[\(statusCode)] \(message)" }
            return message
        case .notLinked:
            return "No CoolKit / eWeLink account linked. Connect under Profile → Connected Accounts."
        case .invalidResponse:
            return "Invalid CoolKit API response"
        }
    }
}

// MARK: - Flexible JSON (CoolKit params / nested blobs)

/// Accepts string/number/bool/null from CoolKit params without failing the whole decode.
enum CoolkitJSONScalar: Decodable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(Int.self) { self = .number(Double(v)) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else { self = .null }
    }

    var display: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.rounded() == n ? String(Int(n)) : String(format: "%.1f", n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "—"
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.rounded() == n ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .string(let s):
            let t = s.lowercased()
            if t == "on" || t == "true" || t == "1" { return true }
            if t == "off" || t == "false" || t == "0" { return false }
            return nil
        case .number(let n): return n != 0
        default: return nil
        }
    }
}

/// Recursive JSON value for raw CoolKit params / timer objects / history blobs.
enum CoolkitJSONValue: Decodable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: CoolkitJSONValue])
    case array([CoolkitJSONValue])
    case null

    init(from decoder: Decoder) throws {
        if var arr = try? decoder.unkeyedContainer() {
            var items: [CoolkitJSONValue] = []
            while !arr.isAtEnd {
                items.append(try arr.decode(CoolkitJSONValue.self))
            }
            self = .array(items)
            return
        }
        if let obj = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dict: [String: CoolkitJSONValue] = [:]
            for key in obj.allKeys {
                dict[key.stringValue] = try obj.decode(CoolkitJSONValue.self, forKey: key)
            }
            self = .object(dict)
            return
        }
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(Int.self) { self = .number(Double(v)) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else { self = .null }
    }

    var display: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.rounded() == n ? String(Int(n)) : String(format: "%.2f", n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "—"
        case .array(let a): return "[\(a.count)]"
        case .object(let o): return "{\(o.count)}"
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n):
            return n.rounded() == n ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}

// MARK: - Device list / status models

/// Live device payload from core-api `GET /api/coolkit/devices`.
struct CoolkitLiveDevice: Decodable, Identifiable, Hashable, Sendable {
    let itemType: Int?
    let deviceId: String
    let name: String
    let online: Bool?
    let uiid: Int?
    let productModel: String?
    let familyId: String?
    let roomId: String?
    let temperature: CoolkitJSONScalar?
    let humidity: CoolkitJSONScalar?
    let `switch`: String?
    let switches: [CoolkitSwitchChannel]?
    let params: [String: CoolkitJSONValue]?

    var id: String { deviceId.isEmpty ? name : deviceId }

    private enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case deviceId = "device_id"
        case name, online, uiid
        case productModel = "product_model"
        case familyId = "family_id"
        case roomId = "room_id"
        case temperature, humidity
        case `switch`, switches, params
    }
}

struct CoolkitSwitchChannel: Codable, Hashable, Sendable {
    let outlet: Int?
    let switchState: String?

    private enum CodingKeys: String, CodingKey {
        case outlet
        case switchState = "switch"
    }

    init(outlet: Int, on: Bool) {
        self.outlet = outlet
        self.switchState = on ? "on" : "off"
    }

    init(outlet: Int?, switchState: String?) {
        self.outlet = outlet
        self.switchState = switchState
    }

    var isOn: Bool { switchState?.lowercased() == "on" }

    func asBodyDict() -> [String: Any] {
        ["outlet": outlet ?? 0, "switch": switchState ?? "off"]
    }
}

struct CoolkitDevicesResponse: Decodable, Sendable {
    let devices: [CoolkitLiveDevice]
    let region: String?
    let apiBase: String?
    let count: Int?
    let total: Int?
    let familyId: String?

    private enum CodingKeys: String, CodingKey {
        case devices, region, count, total
        case apiBase = "api_base"
        case familyId = "family_id"
    }
}

struct CoolkitStatusResponse: Decodable, Sendable {
    let id: String
    let type: Int?
    let params: [String: CoolkitJSONValue]?
    let `switch`: CoolkitJSONValue?
    let switches: [CoolkitSwitchChannel]?
    let timers: [CoolkitJSONValue]?
    let temperature: CoolkitJSONScalar?
    let humidity: CoolkitJSONScalar?
    let region: String?
}

struct CoolkitOkResponse: Decodable, Sendable {
    let id: String?
    let type: Int?
    let ok: Bool?
    let data: CoolkitJSONValue?
}

// MARK: - Switches / batch / families

struct CoolkitSwitchesResponse: Decodable, Sendable {
    let id: String
    let type: Int?
    let switches: [CoolkitSwitchChannel]
    let region: String?
    let ok: Bool?
    let data: CoolkitJSONValue?
}

struct CoolkitBatchStatusResponse: Decodable, Sendable {
    let ok: Bool?
    let respList: [CoolkitJSONValue]?
    let count: Int?
    let region: String?

    private enum CodingKeys: String, CodingKey {
        case ok, count, region
        case respList = "resp_list"
    }
}

struct CoolkitFamilyRoom: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let index: Int?
}

struct CoolkitFamily: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let index: Int?
    let apikey: String?
    let rooms: [CoolkitFamilyRoom]?
}

struct CoolkitFamiliesResponse: Decodable, Sendable {
    let families: [CoolkitFamily]
    let currentFamilyId: String?
    let region: String?
    let count: Int?

    private enum CodingKeys: String, CodingKey {
        case families, region, count
        case currentFamilyId = "current_family_id"
    }
}

// MARK: - Timers

struct CoolkitTimersResponse: Decodable, Sendable {
    let id: String
    let type: Int?
    let timers: [CoolkitJSONValue]
    let count: Int?
    let region: String?
    let note: String?
    let ok: Bool?
    let data: CoolkitJSONValue?
}

// MARK: - Thermostat

struct CoolkitThermostatResponse: Decodable, Sendable {
    let id: String
    let type: Int?
    let mode: String?
    let mainSwitch: String?
    let `switch`: CoolkitJSONValue?
    let autoActive: Bool?
    let sensorType: CoolkitJSONValue?
    let temperature: CoolkitJSONScalar?
    let humidity: CoolkitJSONScalar?
    let targets: CoolkitJSONValue?
    let startup: CoolkitJSONValue?
    let pulse: CoolkitJSONValue?
    let pulseWidth: CoolkitJSONValue?
    let params: [String: CoolkitJSONValue]?
    let region: String?
    let ok: Bool?
    let data: CoolkitJSONValue?

    private enum CodingKeys: String, CodingKey {
        case id, type, mode, targets, startup, pulse, params, region, ok, data
        case `switch`
        case mainSwitch = "main_switch"
        case autoActive = "auto_active"
        case sensorType = "sensor_type"
        case temperature, humidity
        case pulseWidth = "pulse_width"
    }
}

// MARK: - Power / kWh

struct CoolkitPowerResponse: Decodable, Sendable {
    let id: String
    let type: Int?
    let powerW: CoolkitJSONScalar?
    let voltageV: CoolkitJSONScalar?
    let currentA: CoolkitJSONScalar?
    let oneKwh: CoolkitJSONScalar?
    let startTime: String?
    let endTime: String?
    let hundredDaysKwh: [Double]?
    let hundredDaysKwhRaw: String?
    let `switch`: CoolkitJSONValue?
    let params: [String: CoolkitJSONValue]?
    let region: String?
    let activated: Bool?
    let ok: Bool?
    let action: String?
    let data: CoolkitJSONValue?
    /// Present after setPower follow-up (`one_kwh_get` / `hundred_days_kwh`). Nested map, not recursive struct.
    let power: CoolkitJSONValue?

    private enum CodingKeys: String, CodingKey {
        case id, type, params, region, activated, ok, action, data, power
        case `switch`
        case powerW = "power_w"
        case voltageV = "voltage_v"
        case currentA = "current_a"
        case oneKwh = "one_kwh"
        case startTime = "start_time"
        case endTime = "end_time"
        case hundredDaysKwh = "hundred_days_kwh"
        case hundredDaysKwhRaw = "hundred_days_kwh_raw"
    }
}

// MARK: - History

struct CoolkitHistoryItem: Decodable, Hashable, Sendable {
    let deviceId: String?
    let userAgent: CoolkitJSONValue?
    let opsSwitches: CoolkitJSONValue?
    let request: CoolkitJSONValue?
    let opsAccount: CoolkitJSONValue?
    let opsTime: CoolkitJSONValue?
    let raw: CoolkitJSONValue?

    private enum CodingKeys: String, CodingKey {
        case request, raw
        case deviceId = "device_id"
        case userAgent = "user_agent"
        case opsSwitches = "ops_switches"
        case opsAccount = "ops_account"
        case opsTime = "ops_time"
    }
}

struct CoolkitHistoryResponse: Decodable, Sendable {
    let id: String
    let histories: [CoolkitHistoryItem]
    let count: Int?
    let region: String?
    let ok: Bool?
    let cleared: Bool?
}

// MARK: - Settings (pulse / startup / LED)

struct CoolkitDeviceSettingsResponse: Decodable, Sendable {
    let id: String
    let type: Int?
    let startup: CoolkitJSONValue?
    let pulse: CoolkitJSONValue?
    let pulseWidth: CoolkitJSONValue?
    let sledOnline: CoolkitJSONValue?
    let pulses: CoolkitJSONValue?
    let configure: CoolkitJSONValue?
    let params: [String: CoolkitJSONValue]?
    let region: String?
    let ok: Bool?
    let data: CoolkitJSONValue?

    private enum CodingKeys: String, CodingKey {
        case id, type, startup, pulse, pulses, configure, params, region, ok, data
        case pulseWidth = "pulse_width"
        case sledOnline = "sled_online"
    }
}

// MARK: - WebSocket dispatch

struct CoolkitWsDispatchInfo: Decodable, Sendable {
    let ip: String?
    let port: Int?
    let domain: String?
}

struct CoolkitWsHeartbeat: Decodable, Sendable {
    let send: String?
    let intervalHintSec: Int?
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case send, note
        case intervalHintSec = "interval_hint_sec"
    }
}

struct CoolkitWsDispatchResponse: Decodable, Sendable {
    let region: String?
    let dispatch: CoolkitWsDispatchInfo?
    let wssUrl: String?
    let handshake: [String: CoolkitJSONValue]?
    let heartbeat: CoolkitWsHeartbeat?
    let usage: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case region, dispatch, handshake, heartbeat, usage
        case wssUrl = "wss_url"
    }
}

// MARK: - Room domain

struct CoolkitRoomSettings: Decodable, Hashable, Sendable {
    let userId: Int?
    let familyId: String?
    let homeName: String?
    let sampleIntervalSec: Int?

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case familyId = "family_id"
        case homeName = "home_name"
        case sampleIntervalSec = "sample_interval_sec"
    }
}

struct CoolkitDeviceBinding: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let role: String
    let deviceId: String
    let outlet: Int?
    let familyId: String?
    let label: String?
    let productModel: String?
    let uiid: Int?
    let hasDevicekey: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, role, outlet, label, uiid
        case deviceId = "device_id"
        case familyId = "family_id"
        case productModel = "product_model"
        case hasDevicekey = "has_devicekey"
    }
}

struct CoolkitServerLoop: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let deviceId: String
    let outlet: Int?
    let onSeconds: Int?
    let offSeconds: Int?
    let onMinutes: Int?
    let offMinutes: Int?
    let phase: String?
    let phaseStartedAt: String?
    let enabled: Bool
    let lastTickAt: String?
    let lastError: String?
    let source: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, outlet, phase, enabled, source
        case deviceId = "device_id"
        case onSeconds = "on_seconds"
        case offSeconds = "off_seconds"
        case onMinutes = "on_minutes"
        case offMinutes = "off_minutes"
        case phaseStartedAt = "phase_started_at"
        case lastTickAt = "last_tick_at"
        case lastError = "last_error"
    }

    var cycleSummary: String {
        let on = onMinutes ?? ((onSeconds ?? 0) / 60)
        let off = offMinutes ?? ((offSeconds ?? 0) / 60)
        return "\(on) min ON · \(off) min OFF"
    }
}

struct CoolkitRoomResponse: Decodable, Sendable {
    let settings: CoolkitRoomSettings?
    let bindings: [CoolkitDeviceBinding]?
    let loops: [CoolkitServerLoop]?
}

struct CoolkitRoomSettingsEnvelope: Decodable, Sendable {
    let settings: CoolkitRoomSettings?
}

struct CoolkitRoomSeedResponse: Decodable, Sendable {
    let bindings: [CoolkitDeviceBinding]?
    let loopsCreated: Int?
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case bindings, note
        case loopsCreated = "loops_created"
    }
}

struct CoolkitRoomReconcileResponse: Decodable, Sendable {
    let matched: Int?
    let bindings: [CoolkitDeviceBinding]?
    let devices: Int?
    let familyId: String?
    let region: String?

    private enum CodingKeys: String, CodingKey {
        case matched, bindings, devices, region
        case familyId = "family_id"
    }
}

struct CoolkitServerLoopsResponse: Decodable, Sendable {
    let loops: [CoolkitServerLoop]
}

struct CoolkitSceneResponse: Decodable, Sendable {
    let name: String?
    let thingList: CoolkitJSONValue?
    let result: CoolkitJSONValue?

    private enum CodingKeys: String, CodingKey {
        case name, result
        case thingList = "thing_list"
    }
}

struct CoolkitThSample: Decodable, Identifiable, Hashable, Sendable {
    let sampleId: Int?
    let deviceId: String
    let tempC: Double?
    let humidityRH: Double?
    let source: String?
    let sampledAt: String?

    var id: String {
        if let sampleId { return "s-\(sampleId)" }
        return "\(deviceId)-\(sampledAt ?? "")"
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case sampleId = "id"
        case deviceId = "device_id"
        case tempC = "temp_c"
        case humidityRH = "humidity_rh"
        case sampledAt = "sampled_at"
    }
}

struct CoolkitSamplesResponse: Decodable, Sendable {
    let samples: [CoolkitThSample]
    let count: Int?
}

// MARK: - Client

/// core-api CoolKit proxy client (`/api/coolkit/*`).
///
/// App never talks to CoolKit with APP secret — only JWT → core-api, which
/// holds `COOLKIT_APP_*` and the user's encrypted oauth credential.
final class MantarlifeCoolkitAPI: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = AuthConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        decoder = JSONDecoder()
    }

    // MARK: Devices

    /// `GET /coolkit/devices` — optional `family_id` for MantarLife home filter.
    func listDevices(
        accessToken: String,
        familyId: String? = nil,
        num: Int? = nil,
        beginIndex: Int? = nil
    ) async throws -> CoolkitDevicesResponse {
        var query: [String: String] = [:]
        if let familyId, !familyId.isEmpty { query["family_id"] = familyId }
        if let num { query["num"] = String(num) }
        if let beginIndex { query["begin_index"] = String(beginIndex) }
        return try await request(
            "/coolkit/devices",
            accessToken: accessToken,
            query: query,
            mapNotLinked: true
        )
    }

    /// `GET /coolkit/devices/status`
    func getStatus(
        accessToken: String,
        deviceId: String,
        type: Int = 1,
        params: String? = nil
    ) async throws -> CoolkitStatusResponse {
        var query: [String: String] = ["id": deviceId, "type": String(type)]
        if let params, !params.isEmpty { query["params"] = params }
        return try await request(
            "/coolkit/devices/status",
            accessToken: accessToken,
            query: query
        )
    }

    /// `POST /coolkit/devices/status` — raw CoolKit params escape hatch.
    @discardableResult
    func setStatus(
        accessToken: String,
        deviceId: String,
        params: [String: Any],
        type: Int = 1
    ) async throws -> CoolkitOkResponse {
        try await request(
            "/coolkit/devices/status",
            method: "POST",
            accessToken: accessToken,
            json: ["id": deviceId, "type": type, "params": params]
        )
    }

    /// Convenience: single-channel on/off via raw status.
    func setSwitch(accessToken: String, deviceId: String, on: Bool, type: Int = 1) async throws {
        _ = try await setStatus(
            accessToken: accessToken,
            deviceId: deviceId,
            params: ["switch": on ? "on" : "off"],
            type: type
        )
    }

    // MARK: Dual / multi-channel switches (DUALR3)

    /// `GET /coolkit/devices/switches`
    func getSwitches(
        accessToken: String,
        deviceId: String,
        type: Int = 1
    ) async throws -> CoolkitSwitchesResponse {
        try await request(
            "/coolkit/devices/switches",
            accessToken: accessToken,
            query: ["id": deviceId, "type": String(type)]
        )
    }

    /// `POST /coolkit/devices/switches` — multi outlet array.
    @discardableResult
    func setSwitches(
        accessToken: String,
        deviceId: String,
        switches: [CoolkitSwitchChannel],
        type: Int = 1
    ) async throws -> CoolkitSwitchesResponse {
        try await request(
            "/coolkit/devices/switches",
            method: "POST",
            accessToken: accessToken,
            json: [
                "id": deviceId,
                "type": type,
                "switches": switches.map { $0.asBodyDict() },
            ]
        )
    }

    /// Single outlet convenience.
    @discardableResult
    func setOutlet(
        accessToken: String,
        deviceId: String,
        outlet: Int,
        on: Bool,
        type: Int = 1
    ) async throws -> CoolkitSwitchesResponse {
        try await request(
            "/coolkit/devices/switches",
            method: "POST",
            accessToken: accessToken,
            json: [
                "id": deviceId,
                "type": type,
                "outlet": outlet,
                "switch": on ? "on" : "off",
            ]
        )
    }

    // MARK: Batch / scenes

    /// `POST /coolkit/devices/batch-status` — max 10 devices.
    ///
    /// Each item: `{ "id": "…", "type"?: 1, "params": { … } }`
    @discardableResult
    func batchSetStatus(
        accessToken: String,
        thingList: [[String: Any]],
        timeoutMs: Int = 0
    ) async throws -> CoolkitBatchStatusResponse {
        try await request(
            "/coolkit/devices/batch-status",
            method: "POST",
            accessToken: accessToken,
            json: ["thingList": thingList, "timeout": timeoutMs]
        )
    }

    // MARK: Timers (device-native; grow loops stay on core-api)

    /// `GET /coolkit/devices/timers`
    func getTimers(
        accessToken: String,
        deviceId: String,
        type: Int = 1
    ) async throws -> CoolkitTimersResponse {
        try await request(
            "/coolkit/devices/timers",
            accessToken: accessToken,
            query: ["id": deviceId, "type": String(type)]
        )
    }

    /// Full timer array replace.
    @discardableResult
    func setTimers(
        accessToken: String,
        deviceId: String,
        timers: [[String: Any]],
        type: Int = 1
    ) async throws -> CoolkitTimersResponse {
        try await request(
            "/coolkit/devices/timers",
            method: "POST",
            accessToken: accessToken,
            json: ["id": deviceId, "type": type, "timers": timers]
        )
    }

    /// Convenience duration loop (e.g. 5 min on / 15 min off). Optional `outlet` for DUALR3 channel.
    @discardableResult
    func setLoopTimer(
        accessToken: String,
        deviceId: String,
        onMinutes: Int,
        offMinutes: Int,
        outlet: Int? = nil,
        startSwitch: String = "on",
        enabled: Bool = true,
        keepExisting: Bool = false,
        type: Int = 1
    ) async throws -> CoolkitTimersResponse {
        var loop: [String: Any] = [
            "on_minutes": onMinutes,
            "off_minutes": offMinutes,
            "start_switch": startSwitch,
            "enabled": enabled ? 1 : 0,
        ]
        if let outlet { loop["outlet"] = outlet }
        var body: [String: Any] = [
            "id": deviceId,
            "type": type,
            "loop": loop,
        ]
        if keepExisting { body["keep_existing"] = true }
        return try await request(
            "/coolkit/devices/timers",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    // MARK: Thermostat (TH Fan / Petek)

    /// `GET /coolkit/devices/thermostat`
    func getThermostat(
        accessToken: String,
        deviceId: String,
        type: Int = 1
    ) async throws -> CoolkitThermostatResponse {
        try await request(
            "/coolkit/devices/thermostat",
            accessToken: accessToken,
            query: ["id": deviceId, "type": String(type)]
        )
    }

    /// Auto temperature/humidity targets, or manual `mode: normal`.
    ///
    /// - Auto: `mode` = `"temperature"` | `"humidity"`, plus `high` / `low`
    /// - Manual: `mode` = `"normal"`, optional `switch` / `mainSwitch`
    /// - Heating default (Petek): below low → on, above high → off
    /// - Fan/cool override: pass `highSwitch` / `lowSwitch`
    @discardableResult
    func setThermostat(
        accessToken: String,
        deviceId: String,
        mode: String,
        high: Double? = nil,
        low: Double? = nil,
        mainSwitch: String? = nil,
        switchState: String? = nil,
        highSwitch: String? = nil,
        lowSwitch: String? = nil,
        type: Int = 1
    ) async throws -> CoolkitThermostatResponse {
        var body: [String: Any] = [
            "id": deviceId,
            "type": type,
            "mode": mode,
        ]
        if let high { body["high"] = high }
        if let low { body["low"] = low }
        if let mainSwitch { body["main_switch"] = mainSwitch }
        if let switchState { body["switch"] = switchState }
        if let highSwitch { body["high_switch"] = highSwitch }
        if let lowSwitch { body["low_switch"] = lowSwitch }
        return try await request(
            "/coolkit/devices/thermostat",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    /// Raw params escape hatch for thermostat UIID fields.
    @discardableResult
    func setThermostatRaw(
        accessToken: String,
        deviceId: String,
        params: [String: Any],
        type: Int = 1
    ) async throws -> CoolkitThermostatResponse {
        try await request(
            "/coolkit/devices/thermostat",
            method: "POST",
            accessToken: accessToken,
            json: ["id": deviceId, "type": type, "params": params]
        )
    }

    // MARK: Power / kWh (POWR, DUALR3 tüketim)

    /// `GET /coolkit/devices/power` — set `activate` to send `uiActive:60` first.
    func getPower(
        accessToken: String,
        deviceId: String,
        type: Int = 1,
        activate: Bool = false
    ) async throws -> CoolkitPowerResponse {
        var query: [String: String] = ["id": deviceId, "type": String(type)]
        if activate { query["activate"] = "1" }
        return try await request(
            "/coolkit/devices/power",
            accessToken: accessToken,
            query: query
        )
    }

    /// Power action: `ui_active` | `one_kwh_start` | `one_kwh_stop` | `one_kwh_get` | `hundred_days_kwh`
    @discardableResult
    func setPower(
        accessToken: String,
        deviceId: String,
        action: String,
        seconds: Int? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        type: Int = 1
    ) async throws -> CoolkitPowerResponse {
        var body: [String: Any] = [
            "id": deviceId,
            "type": type,
            "action": action,
        ]
        if let seconds { body["seconds"] = seconds }
        if let startTime { body["start_time"] = startTime }
        if let endTime { body["end_time"] = endTime }
        return try await request(
            "/coolkit/devices/power",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    // MARK: History (Kayıtlar)

    /// `GET /coolkit/devices/history` — max 30.
    func getHistory(
        accessToken: String,
        deviceId: String,
        num: Int = 30,
        from: Int? = nil
    ) async throws -> CoolkitHistoryResponse {
        var query: [String: String] = [
            "id": deviceId,
            "num": String(min(30, max(1, num))),
        ]
        if let from { query["from"] = String(from) }
        return try await request(
            "/coolkit/devices/history",
            accessToken: accessToken,
            query: query
        )
    }

    /// `DELETE /coolkit/devices/history`
    @discardableResult
    func clearHistory(
        accessToken: String,
        deviceId: String
    ) async throws -> CoolkitHistoryResponse {
        try await request(
            "/coolkit/devices/history",
            method: "DELETE",
            accessToken: accessToken,
            query: ["id": deviceId]
        )
    }

    // MARK: Settings (inching / power-on / LED)

    /// `GET /coolkit/devices/settings`
    func getDeviceSettings(
        accessToken: String,
        deviceId: String,
        type: Int = 1
    ) async throws -> CoolkitDeviceSettingsResponse {
        try await request(
            "/coolkit/devices/settings",
            accessToken: accessToken,
            query: ["id": deviceId, "type": String(type)]
        )
    }

    /// Pulse / startup / sled_online (single-channel).
    @discardableResult
    func setDeviceSettings(
        accessToken: String,
        deviceId: String,
        pulse: String? = nil,
        pulseWidthMs: Int? = nil,
        startup: String? = nil,
        sledOnline: String? = nil,
        type: Int = 1
    ) async throws -> CoolkitDeviceSettingsResponse {
        var body: [String: Any] = ["id": deviceId, "type": type]
        if let pulse { body["pulse"] = pulse }
        if let pulseWidthMs { body["pulse_width"] = pulseWidthMs }
        if let startup { body["startup"] = startup }
        if let sledOnline { body["sled_online"] = sledOnline }
        return try await request(
            "/coolkit/devices/settings",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    /// Multi-channel pulses/configure or raw params.
    @discardableResult
    func setDeviceSettingsRaw(
        accessToken: String,
        deviceId: String,
        body: [String: Any],
        type: Int = 1
    ) async throws -> CoolkitDeviceSettingsResponse {
        var payload = body
        payload["id"] = deviceId
        payload["type"] = type
        return try await request(
            "/coolkit/devices/settings",
            method: "POST",
            accessToken: accessToken,
            json: payload
        )
    }

    // MARK: Families / WS

    /// `GET /coolkit/families` — pick MantarLife `family_id`.
    func listFamilies(accessToken: String) async throws -> CoolkitFamiliesResponse {
        try await request("/coolkit/families", accessToken: accessToken)
    }

    /// `GET /coolkit/ws/dispatch` — wss URL + `userOnline` handshake for live TH.
    func getWsDispatch(accessToken: String) async throws -> CoolkitWsDispatchResponse {
        try await request("/coolkit/ws/dispatch", accessToken: accessToken)
    }

    // MARK: Native once / countdown timers

    @discardableResult
    func setCountdownTimer(
        accessToken: String,
        deviceId: String,
        minutes: Int,
        switchState: String = "off",
        outlet: Int? = nil,
        keepExisting: Bool = true,
        type: Int = 1
    ) async throws -> CoolkitTimersResponse {
        var countdown: [String: Any] = [
            "minutes": minutes,
            "switch": switchState,
            "enabled": 1,
        ]
        if let outlet { countdown["outlet"] = outlet }
        var body: [String: Any] = [
            "id": deviceId,
            "type": type,
            "countdown": countdown,
        ]
        if keepExisting { body["keep_existing"] = true }
        return try await request(
            "/coolkit/devices/timers",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    @discardableResult
    func setOnceTimer(
        accessToken: String,
        deviceId: String,
        atISO8601: String,
        switchState: String = "on",
        outlet: Int? = nil,
        keepExisting: Bool = true,
        type: Int = 1
    ) async throws -> CoolkitTimersResponse {
        var once: [String: Any] = [
            "at": atISO8601,
            "switch": switchState,
            "enabled": 1,
        ]
        if let outlet { once["outlet"] = outlet }
        var body: [String: Any] = [
            "id": deviceId,
            "type": type,
            "once": once,
        ]
        if keepExisting { body["keep_existing"] = true }
        return try await request(
            "/coolkit/devices/timers",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    // MARK: Room domain (bindings, server loops, scenes, samples)

    func getRoom(accessToken: String) async throws -> CoolkitRoomResponse {
        try await request("/coolkit/room", accessToken: accessToken)
    }

    @discardableResult
    func updateRoomSettings(
        accessToken: String,
        familyId: String? = nil,
        homeName: String? = nil,
        sampleIntervalSec: Int? = nil
    ) async throws -> CoolkitRoomSettingsEnvelope {
        var body: [String: Any] = [:]
        if let familyId { body["family_id"] = familyId }
        if let homeName { body["home_name"] = homeName }
        if let sampleIntervalSec { body["sample_interval_sec"] = sampleIntervalSec }
        return try await request(
            "/coolkit/room",
            method: "PUT",
            accessToken: accessToken,
            json: body
        )
    }

    @discardableResult
    func seedRoom(accessToken: String) async throws -> CoolkitRoomSeedResponse {
        try await request("/coolkit/room/seed", method: "POST", accessToken: accessToken, json: [:])
    }

    @discardableResult
    func reconcileRoom(accessToken: String) async throws -> CoolkitRoomReconcileResponse {
        try await request("/coolkit/room/reconcile", method: "POST", accessToken: accessToken, json: [:])
    }

    func listServerLoops(accessToken: String) async throws -> CoolkitServerLoopsResponse {
        try await request("/coolkit/room/loops", accessToken: accessToken)
    }

    @discardableResult
    func createServerLoop(
        accessToken: String,
        name: String,
        deviceId: String,
        onMinutes: Int,
        offMinutes: Int,
        outlet: Int? = nil,
        enabled: Bool = false
    ) async throws -> CoolkitServerLoop {
        var body: [String: Any] = [
            "name": name,
            "device_id": deviceId,
            "on_minutes": onMinutes,
            "off_minutes": offMinutes,
            "enabled": enabled,
        ]
        if let outlet { body["outlet"] = outlet }
        return try await request(
            "/coolkit/room/loops",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    @discardableResult
    func setServerLoopEnabled(
        accessToken: String,
        loopId: Int,
        enabled: Bool
    ) async throws -> CoolkitServerLoop {
        try await request(
            "/coolkit/room/loops/\(loopId)/enable",
            method: "POST",
            accessToken: accessToken,
            json: ["enabled": enabled]
        )
    }

    @discardableResult
    func runScene(accessToken: String, name: String) async throws -> CoolkitSceneResponse {
        try await request(
            "/coolkit/room/scenes/\(name)",
            method: "POST",
            accessToken: accessToken,
            json: [:]
        )
    }

    func getSamples(
        accessToken: String,
        deviceId: String? = nil,
        limit: Int = 288
    ) async throws -> CoolkitSamplesResponse {
        var query: [String: String] = ["limit": String(limit)]
        if let deviceId { query["device_id"] = deviceId }
        return try await request("/coolkit/room/samples", accessToken: accessToken, query: query)
    }

    @discardableResult
    func postSample(
        accessToken: String,
        deviceId: String,
        tempC: Double?,
        humidityRH: Double?,
        source: String = "ws"
    ) async throws -> CoolkitThSample {
        var body: [String: Any] = [
            "device_id": deviceId,
            "source": source,
        ]
        if let tempC { body["temp_c"] = tempC }
        if let humidityRH { body["humidity_rh"] = humidityRH }
        return try await request(
            "/coolkit/room/samples",
            method: "POST",
            accessToken: accessToken,
            json: body
        )
    }

    // MARK: Transport

    /// Mirrors IDSCredentialsAPI: `AuthConfig.baseURL` is host root (`https://qline.tech`),
    /// API paths hang under `/api/…`.
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        accessToken: String,
        query: [String: String] = [:],
        json: [String: Any]? = nil,
        mapNotLinked: Bool = false
    ) async throws -> T {
        let root = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api"
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        var components = URLComponents(string: root + normalized)
        if !query.isEmpty {
            components?.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw MantarlifeAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if mapNotLinked, status == 404 {
            throw MantarlifeAPIError.notLinked
        }
        guard (200..<300).contains(status) else {
            if status == 404, (errorMessage(from: data) ?? "").lowercased().contains("coolkit") {
                throw MantarlifeAPIError.notLinked
            }
            throw MantarlifeAPIError.api(
                message: errorMessage(from: data) ?? "Request failed",
                statusCode: status
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MantarlifeAPIError.api(
                message: coolkitDecodeFailureMessage(error),
                statusCode: status
            )
        }
    }

    private func errorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let detail: String?
            let message: String?
            let error: String?
        }
        let response = try? decoder.decode(ErrorResponse.self, from: data)
        return [response?.detail, response?.message, response?.error]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private func coolkitDecodeFailureMessage(_ error: Error) -> String {
    let detail: String
    let path: [CodingKey]
    switch error {
    case DecodingError.keyNotFound(let key, let context):
        detail = "Missing key '\(key.stringValue)': \(context.debugDescription)"
        path = context.codingPath + [key]
    case DecodingError.typeMismatch(_, let context):
        detail = "Type mismatch: \(context.debugDescription)"
        path = context.codingPath
    case DecodingError.valueNotFound(_, let context):
        detail = "Missing value: \(context.debugDescription)"
        path = context.codingPath
    case DecodingError.dataCorrupted(let context):
        detail = "Invalid data: \(context.debugDescription)"
        path = context.codingPath
    default:
        return "Decode failed: \(error.localizedDescription)"
    }
    let location = path.map(\.stringValue).joined(separator: ".")
    return location.isEmpty ? "Decode failed: \(detail)" : "Decode failed at \(location): \(detail)"
}
