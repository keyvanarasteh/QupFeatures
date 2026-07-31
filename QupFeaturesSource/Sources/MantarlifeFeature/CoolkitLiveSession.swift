import Foundation

/// Live CoolKit WSS session (dispatch handshake + heartbeats).
/// Falls back to poll when dispatch is unavailable (Standard Role / network).
@MainActor
final class CoolkitLiveSession: ObservableObject {
    enum Mode: String {
        case idle
        case websocket
        case poll
        case failed
    }

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var lastTemperature: Double?
    @Published private(set) var lastHumidity: Double?
    @Published private(set) var lastDeviceId: String?
    @Published private(set) var lastUpdate: Date?

    private let api = MantarlifeCoolkitAPI()
    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var accessToken: String = ""
    private var preferredDeviceId: String?

    func start(accessToken: String, preferredDeviceId: String?, pollDeviceIds: [String] = []) async {
        stop()
        self.accessToken = accessToken
        self.preferredDeviceId = preferredDeviceId
        lastError = nil

        do {
            let dispatch = try await api.getWsDispatch(accessToken: accessToken)
            guard let wss = dispatch.wssUrl, let url = URL(string: wss) else {
                throw MantarlifeAPIError.api(message: "No WSS URL from dispatch", statusCode: 502)
            }
            let handshake = dispatch.handshake ?? [:]
            let hbSec = max(20, dispatch.heartbeat?.intervalHintSec ?? 90)

            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default)
            let ws = session.webSocketTask(with: request)
            self.task = ws
            ws.resume()

            // Send userOnline handshake
            let handshakeJSON = try Self.encodeHandshake(handshake)
            try await ws.send(.string(handshakeJSON))

            mode = .websocket
            receiveTask = Task { [weak self] in
                await self?.receiveLoop(ws)
            }
            heartbeatTask = Task { [weak self] in
                await self?.heartbeatLoop(ws, intervalSec: hbSec)
            }
        } catch {
            lastError = error.localizedDescription
            mode = .poll
            let ids = pollDeviceIds.isEmpty
                ? (preferredDeviceId.map { [$0] } ?? [])
                : pollDeviceIds
            startPolling(deviceIds: ids)
        }
    }

    func stop() {
        heartbeatTask?.cancel()
        receiveTask?.cancel()
        pollTask?.cancel()
        heartbeatTask = nil
        receiveTask = nil
        pollTask = nil
        task?.cancel()
        task = nil
        if mode != .failed {
            mode = .idle
        }
    }

    private func startPolling(deviceIds: [String]) {
        pollTask?.cancel()
        guard !deviceIds.isEmpty else {
            mode = .failed
            return
        }
        mode = .poll
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                for id in deviceIds {
                    if Task.isCancelled { return }
                    do {
                        let th = try await api.getThermostat(accessToken: accessToken, deviceId: id)
                        await MainActor.run {
                            if let t = th.temperature?.doubleValue {
                                self.lastTemperature = t
                            }
                            if let h = th.humidity?.doubleValue {
                                self.lastHumidity = h
                            }
                            self.lastDeviceId = id
                            self.lastUpdate = Date()
                            self.lastError = nil
                        }
                        // Push sample best-effort
                        if let t = th.temperature?.doubleValue ?? lastTemperature {
                            _ = try? await api.postSample(
                                accessToken: accessToken,
                                deviceId: id,
                                tempC: t,
                                humidityRH: th.humidity?.doubleValue,
                                source: "poll"
                            )
                        }
                    } catch {
                        await MainActor.run {
                            self.lastError = error.localizedDescription
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func heartbeatLoop(_ ws: URLSessionWebSocketTask, intervalSec: Int) async {
        let payload = "ping"
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(intervalSec) * 1_000_000_000)
            if Task.isCancelled { return }
            do {
                try await ws.send(.string(payload))
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.mode = .failed
                }
                return
            }
        }
    }

    private func receiveLoop(_ ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    if self.mode == .websocket {
                        self.mode = .failed
                    }
                }
                return
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let action = (obj["action"] as? String) ?? ""
        if action == "pong" || text == "pong" { return }

        var params = obj["params"] as? [String: Any]
        if params == nil, let nested = obj["data"] as? [String: Any] {
            params = nested["params"] as? [String: Any] ?? nested
        }
        guard let params else { return }

        let deviceId = (obj["deviceid"] as? String)
            ?? (obj["device_id"] as? String)
            ?? preferredDeviceId

        if let t = Self.double(from: params["currentTemperature"] ?? params["temperature"]) {
            lastTemperature = t
        }
        if let h = Self.double(from: params["currentHumidity"] ?? params["humidity"]) {
            lastHumidity = h
        }
        if lastTemperature != nil || lastHumidity != nil {
            lastDeviceId = deviceId
            lastUpdate = Date()
            lastError = nil
            if let deviceId, let token = Optional(accessToken), !token.isEmpty {
                Task {
                    _ = try? await api.postSample(
                        accessToken: token,
                        deviceId: deviceId,
                        tempC: lastTemperature,
                        humidityRH: lastHumidity,
                        source: "ws"
                    )
                }
            }
        }
    }

    private static func double(from value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s)
        case let n as NSNumber: return n.doubleValue
        default: return nil
        }
    }

    private static func encodeHandshake(_ handshake: [String: CoolkitJSONValue]) throws -> String {
        // Re-encode via JSONSerialization by converting CoolkitJSONValue → Any
        func any(from v: CoolkitJSONValue) -> Any {
            switch v {
            case .null: return NSNull()
            case .bool(let b): return b
            case .number(let n): return n
            case .string(let s): return s
            case .array(let a): return a.map(any(from:))
            case .object(let o): return o.mapValues(any(from:))
            }
        }
        let dict = handshake.mapValues(any(from:))
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        guard let s = String(data: data, encoding: .utf8) else {
            throw MantarlifeAPIError.invalidResponse
        }
        return s
    }
}

