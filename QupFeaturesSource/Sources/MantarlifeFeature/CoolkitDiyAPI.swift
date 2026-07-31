import Foundation

/// Local **DIY Mode** client (plaintext HTTP `:8081/zeroconf/*`).
///
/// Secondary path only — primary control is CoolKit cloud via `MantarlifeCoolkitAPI`.
/// Requires: device in DIY Mode, phone/host on same LAN, reachable `http://<ip>:8081`.
/// No devicekey. Do not use from a browser HTTPS origin (mixed content); native OK.
final class CoolkitDiyAPI: Sendable {
    private let session: URLSession
    private let port: Int

    init(session: URLSession = .shared, port: Int = 8081) {
        self.session = session
        self.port = port
    }

    /// `POST /zeroconf/info`
    func info(host: String, deviceId: String) async throws -> [String: Any] {
        try await post(host: host, path: "info", deviceId: deviceId, data: [:])
    }

    /// `POST /zeroconf/switch` — single channel.
    @discardableResult
    func setSwitch(host: String, deviceId: String, on: Bool) async throws -> [String: Any] {
        try await post(
            host: host,
            path: "switch",
            deviceId: deviceId,
            data: ["switch": on ? "on" : "off"]
        )
    }

    /// `POST /zeroconf/switches` — multi-channel (DUALR3).
    @discardableResult
    func setSwitches(
        host: String,
        deviceId: String,
        outlets: [(outlet: Int, on: Bool)]
    ) async throws -> [String: Any] {
        let switches = outlets.map { ["outlet": $0.outlet, "switch": $0.on ? "on" : "off"] as [String: Any] }
        return try await post(
            host: host,
            path: "switches",
            deviceId: deviceId,
            data: ["switches": switches]
        )
    }

    /// `POST /zeroconf/signal_strength`
    func signalStrength(host: String, deviceId: String) async throws -> [String: Any] {
        try await post(host: host, path: "signal_strength", deviceId: deviceId, data: [:])
    }

    /// `POST /zeroconf/wifi` — re-pair SSID while in DIY Mode.
    @discardableResult
    func setWifi(
        host: String,
        deviceId: String,
        ssid: String,
        password: String
    ) async throws -> [String: Any] {
        try await post(
            host: host,
            path: "wifi",
            deviceId: deviceId,
            data: ["ssid": ssid, "password": password]
        )
    }

    // MARK: - Transport

    private func post(
        host: String,
        path: String,
        deviceId: String,
        data: [String: Any]
    ) async throws -> [String: Any] {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty,
              let url = URL(string: "http://\(cleanHost):\(port)/zeroconf/\(path)")
        else {
            throw MantarlifeAPIError.invalidResponse
        }

        // DIY frame (ar-ge/api.md §2)
        let body: [String: Any] = [
            "deviceid": deviceId,
            "data": data,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (respData, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let msg = String(data: respData, encoding: .utf8) ?? "DIY request failed"
            throw MantarlifeAPIError.api(message: msg, statusCode: status)
        }

        let obj = try JSONSerialization.jsonObject(with: respData)
        guard let dict = obj as? [String: Any] else {
            throw MantarlifeAPIError.invalidResponse
        }
        if let err = dict["error"] as? Int, err != 0 {
            throw MantarlifeAPIError.api(
                message: "DIY error \(err)",
                statusCode: status
            )
        }
        return dict
    }
}
