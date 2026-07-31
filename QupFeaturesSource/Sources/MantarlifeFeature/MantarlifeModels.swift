import Foundation

/// Inventory extracted from `MantarLife/ar-ge/environment.md` (SONOFF / eWeLink
/// screenshots of the live grow room under home profile "MantarLife").
public enum MantarlifeRoom {
    public static let homeName = "MantarLife"
    public static let sourceDoc = "ar-ge/environment.md"
}

public enum MantarlifeDeviceKind: String, Sendable, CaseIterable {
    case thSwitch = "TH switch"
    case dualRelay = "Dual relay"
    case dualChannel = "Dual channel"

    public var systemImage: String {
        switch self {
        case .thSwitch: return "thermometer.medium"
        case .dualRelay: return "switch.2"
        case .dualChannel: return "drop.degreesign"
        }
    }
}

public struct MantarlifeDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let nameTR: String
    public let kind: MantarlifeDeviceKind
    public let model: String
    public let manufacturer: String
    public let mac: String?
    public let firmware: String?
    public let fwVersion: String?
    public let role: String
    /// Snapshot telemetry from ar-ge capture (not live API).
    public let snapshotTempC: Double?
    public let snapshotHumidityRH: Double?
    public let channels: [String]

    public init(
        id: String,
        name: String,
        nameTR: String,
        kind: MantarlifeDeviceKind,
        model: String,
        manufacturer: String = "SONOFF",
        mac: String? = nil,
        firmware: String? = nil,
        fwVersion: String? = nil,
        role: String,
        snapshotTempC: Double? = nil,
        snapshotHumidityRH: Double? = nil,
        channels: [String] = []
    ) {
        self.id = id
        self.name = name
        self.nameTR = nameTR
        self.kind = kind
        self.model = model
        self.manufacturer = manufacturer
        self.mac = mac
        self.firmware = firmware
        self.fwVersion = fwVersion
        self.role = role
        self.snapshotTempC = snapshotTempC
        self.snapshotHumidityRH = snapshotHumidityRH
        self.channels = channels
    }
}

public struct MantarlifeLoopTimer: Identifiable, Hashable, Sendable {
    public let id: String
    public let target: String
    public let method: String
    public let onMinutes: Int
    public let offMinutes: Int
    public let startTime: String
    public let enabled: Bool

    public var cycleSummary: String {
        "\(onMinutes) min ON · \(offMinutes) min OFF"
    }
}

/// Static room catalog — replace/augment with live data via
/// `MantarlifeCoolkitAPI.listDevices` once CoolKit OAuth is linked
/// (core-api credentials provider=coolkit).
public enum MantarlifeCatalog {
    public static let devices: [MantarlifeDevice] = [
        .init(
            id: "100296b50f",
            name: "Fan",
            nameTR: "Fan",
            kind: .thSwitch,
            model: "THR320D",
            mac: "68:FE:71:3A:5B:0C",
            firmware: "SN-ESP32D0-THR3-01",
            fwVersion: "1.3.0",
            role: "Ventilation / exhaust",
            snapshotTempC: nil,
            snapshotHumidityRH: nil
        ),
        .init(
            id: "petek-th", // ID not fully captured in screenshots; label-stable
            name: "Heater",
            nameTR: "Petek",
            kind: .thSwitch,
            model: "THR320D",
            firmware: "SN-ESP32D0-THR3-01",
            fwVersion: "1.3.0",
            role: "Radiator / heating",
            snapshotTempC: 22.3,
            snapshotHumidityRH: 99.9
        ),
        .init(
            id: "100275a49e",
            name: "Ultrasonic mist",
            nameTR: "Ultrasonik sisleme",
            kind: .dualChannel,
            model: "DUALR3",
            mac: "2043A8C1B1E8",
            firmware: "E32-2SW-P0",
            fwVersion: "1.6.1",
            role: "Ultrasonic fogging channel",
            channels: ["Ultrasonik"]
        ),
        .init(
            id: "100275a48c",
            name: "Misting",
            nameTR: "Sisleme",
            kind: .dualRelay,
            model: "DUALR3",
            mac: "2043A8C05630",
            firmware: "E32-2SW-P0",
            fwVersion: "1.6.1",
            role: "Primary humidification",
            channels: ["Sisleme 1", "Sisleme 2"]
        ),
    ]

    public static let loopTimers: [MantarlifeLoopTimer] = [
        .init(
            id: "loop-ultrasonic",
            target: "Ultrasonik (DUALR3 channel)",
            method: "Alternating (Değişimli)",
            onMinutes: 5,
            offMinutes: 15,
            startTime: "2026-07-15 20:52",
            enabled: true
        ),
        .init(
            id: "loop-general",
            target: "Fan / general switch",
            method: "Alternating (Değişimli)",
            onMinutes: 3,
            offMinutes: 15,
            startTime: "2026-07-08 19:01",
            enabled: true
        ),
    ]

    /// CoolKit regional REST bases from eWeLink API docs.
    public static let coolkitRegions: [(code: String, host: String)] = [
        ("eu", "https://eu-apia.coolkit.cc"),
        ("us", "https://us-apia.coolkit.cc"),
        ("as", "https://as-apia.coolkit.cc"),
        ("cn", "https://cn-apia.coolkit.cn"),
    ]
}
