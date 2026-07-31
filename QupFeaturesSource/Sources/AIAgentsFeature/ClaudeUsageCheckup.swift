import Foundation

struct AgentUsageSnapshot: Sendable, Equatable {
    var limits: [UsageLimit]
    var checkedAt: Date
}

protocol AgentUsageChecking: Sendable {
    func checkUsage(for provider: AgentProvider) async throws -> AgentUsageSnapshot
}

enum ClaudeUsageCheckupError: LocalizedError, Equatable {
    case unavailable
    case timedOut
    case commandFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "The provider CLI was not found in a supported installation location."
        case .timedOut:
            "The provider CLI did not respond within 30 seconds."
        case let .commandFailed(message):
            message.isEmpty ? "The provider CLI could not check usage." : message
        case .invalidResponse:
            "The provider CLI returned JSON, but no usage limits could be read from it."
        }
    }
}

struct LiveAgentUsageChecker: AgentUsageChecking {
    func checkUsage(for provider: AgentProvider) async throws -> AgentUsageSnapshot {
        #if os(macOS)
        return try await Task.detached(priority: .utility) {
            try Self.runCheckup(provider: provider)
        }.value
        #else
        throw ClaudeUsageCheckupError.unavailable
        #endif
    }

    #if os(macOS)
    private static func runCheckup(provider: AgentProvider) throws -> AgentUsageSnapshot {
        guard let command = command(for: provider), let executable = findExecutable(named: command.name) else {
            throw ClaudeUsageCheckupError.unavailable
        }

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = executable
        process.arguments = command.arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.standardInput = FileHandle.nullDevice

        try process.run()
        let deadline = Date().addingTimeInterval(30)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            throw ClaudeUsageCheckupError.timedOut
        }

        let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = standardError.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClaudeUsageCheckupError.commandFailed(message)
        }

        let limits = try AgentUsageResponseParser.parse(output)
        return AgentUsageSnapshot(limits: limits, checkedAt: .now)
    }

    private static func command(for provider: AgentProvider) -> (name: String, arguments: [String])? {
        switch provider {
        case .claude:
            ("claude", ["--print", "/usage", "--output-format", "json"])
        case .codex:
            ("codex", ["exec", "--json", "--ephemeral", "--sandbox", "read-only", "--skip-git-repo-check", "/status"])
        case .grok:
            ("grok", ["--single", "/usage", "--output-format", "json", "--permission-mode", "plan", "--disable-web-search", "--no-memory"])
        default:
            nil
        }
    }

    private static func findExecutable(named name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/\(name)"),
            home.appendingPathComponent(".\(name)/local/\(name)"),
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)"),
            URL(fileURLWithPath: "/usr/bin/\(name)"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
    #endif
}

enum AgentUsageResponseParser {
    static func parse(_ data: Data) throws -> [UsageLimit] {
        var limits: [UsageLimit] = []
        var resultTexts: [String] = []
        for object in try jsonObjects(from: data) {
            collectStructuredLimits(in: object, key: nil, into: &limits)
            collectResultTexts(in: object, into: &resultTexts)
        }
        if limits.isEmpty { limits = resultTexts.flatMap(parseText) }
        guard !limits.isEmpty else { throw ClaudeUsageCheckupError.invalidResponse }
        return limits
    }

    private static func jsonObjects(from data: Data) throws -> [Any] {
        if let object = try? JSONSerialization.jsonObject(with: data) { return [object] }
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        let objects = lines.compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) }
        if objects.isEmpty { throw ClaudeUsageCheckupError.invalidResponse }
        return objects
    }

    private static func collectResultTexts(in value: Any, into texts: inout [String]) {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if ["result", "text", "content", "message"].contains(key), let text = child as? String {
                    texts.append(text)
                } else {
                    collectResultTexts(in: child, into: &texts)
                }
            }
        } else if let array = value as? [Any] {
            for child in array { collectResultTexts(in: child, into: &texts) }
        }
    }

    private static func collectStructuredLimits(in value: Any, key: String?, into limits: inout [UsageLimit]) {
        if let dictionary = value as? [String: Any] {
            if let key,
               let utilization = number(dictionary["utilization"] ?? dictionary["used_percent"] ?? dictionary["percent_used"]),
               isUsageWindow(key) {
                let reset = date(dictionary["resets_at"] ?? dictionary["reset_at"])
                limits.append(UsageLimit(
                    window: window(for: key),
                    usedPercent: utilization,
                    resetsAt: reset,
                    label: label(for: key)
                ))
                return
            }
            for (childKey, child) in dictionary {
                collectStructuredLimits(in: child, key: childKey, into: &limits)
            }
        } else if let array = value as? [Any] {
            for child in array { collectStructuredLimits(in: child, key: key, into: &limits) }
        }
    }

    private static func parseText(_ text: String) -> [UsageLimit] {
        let clean = text.replacingOccurrences(of: #"\u{001B}\[[0-9;]*m"#, with: "", options: .regularExpression)
        let pattern = #"(?im)^\s*([^\n:]+?)(?:\s*:|\s{2,}).*?(\d+(?:\.\d+)?)\s*%[^\n]*(?:reset(?:s)?(?:\s+at|\s+in)?\s*:?\s*([^\n]+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(clean.startIndex..., in: clean)
        return regex.matches(in: clean, range: range).compactMap { match in
            guard let labelRange = Range(match.range(at: 1), in: clean),
                  let percentRange = Range(match.range(at: 2), in: clean),
                  let percent = Double(clean[percentRange]) else { return nil }
            let rawLabel = String(clean[labelRange]).trimmingCharacters(in: .whitespaces)
            let reset = Range(match.range(at: 0), in: clean).flatMap { parseResetText(String(clean[$0])) }
            return UsageLimit(window: window(for: rawLabel), usedPercent: percent, resetsAt: reset, label: rawLabel)
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string.replacingOccurrences(of: "%", with: "")) }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }

    private static func parseResetText(_ value: String) -> Date? {
        let pattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range, in: value) else { return nil }
        return ISO8601DateFormatter().date(from: String(value[range]))
    }

    private static func isUsageWindow(_ key: String) -> Bool {
        let key = key.lowercased()
        return key.contains("hour") || key.contains("day") || key.contains("week") || key.contains("month") || key.contains("session")
    }

    private static func window(for key: String) -> LimitWindow {
        let key = key.lowercased()
        if key.contains("month") { return .monthly }
        if key.contains("day") || key.contains("week") { return .weekly }
        if key.contains("session") || key.contains("hour") { return .session }
        return .weekly
    }

    private static func label(for key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
