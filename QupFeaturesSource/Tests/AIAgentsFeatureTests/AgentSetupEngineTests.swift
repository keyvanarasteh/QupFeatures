#if os(macOS)
import Foundation
import Testing
@testable import AIAgentsFeature

@Suite(.serialized)
struct AgentSetupEngineTests {
    /// Each test gets its own throwaway `$HOME`-shaped prefix/home root so
    /// nothing here ever touches the real machine's `~/.local`, `~/.config`,
    /// or `~/.sandbox`.
    private func withTempHome(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    @Test func setupCreatesWrapperConfigAndData() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.claude, prefix: prefix, home: prefix)
            let paths = AgentSetupEngine.paths(for: .claude, prefix: prefix, home: prefix)
            #expect(FileManager.default.isExecutableFile(atPath: paths.wrapper.path))
            #expect(FileManager.default.fileExists(atPath: paths.configDir.path))
            #expect(FileManager.default.fileExists(atPath: paths.dataDir.path))

            let contents = try String(contentsOf: paths.wrapper, encoding: .utf8)
            #expect(contents.hasPrefix("#!/usr/bin/env bash"))
            #expect(contents.contains("CLAUDE_CONFIG_DIR"))
            #expect(contents.contains("CLAUDE_DATA_DIR"))
        }
    }

    @Test func setupCreatesAliasSymlinkForOpenClaude() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.openclaude, prefix: prefix, home: prefix)
            let paths = AgentSetupEngine.paths(for: .openclaude, prefix: prefix, home: prefix)
            let alias = try #require(paths.alias)
            let destination = try FileManager.default.destinationOfSymbolicLink(atPath: alias.path)
            #expect(destination == "openclaude")
        }
    }

    @Test func checkReportsFailBeforeSetupAndPassAfter() throws {
        try withTempHome { prefix in
            let before = AgentSetupEngine.check(.codex, prefix: prefix, home: prefix)
            #expect(!before.isHealthy)
            #expect(before.failCount == before.items.count)

            try AgentSetupEngine.setup(.codex, prefix: prefix, home: prefix)
            let after = AgentSetupEngine.check(.codex, prefix: prefix, home: prefix)
            #expect(after.isHealthy)
            #expect(after.failCount == 0)
        }
    }

    @Test func verifyIncludesShebangAndEnvVarChecksOnlyAfterSetup() throws {
        try withTempHome { prefix in
            let before = AgentSetupEngine.verify(.grok, prefix: prefix, home: prefix)
            #expect(!before.items.contains { $0.id == "shebang" })

            try AgentSetupEngine.setup(.grok, prefix: prefix, home: prefix)
            let after = AgentSetupEngine.verify(.grok, prefix: prefix, home: prefix)
            #expect(after.items.contains { $0.id == "shebang" && $0.status == .pass })
            #expect(after.items.contains { $0.id == "config-var" && $0.status == .pass })
            #expect(after.items.contains { $0.id == "data-var" && $0.status == .pass })
            #expect(after.isHealthy)
        }
    }

    @Test func verifyFlagsAliasPointingAtWrongTarget() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.opencode, prefix: prefix, home: prefix)
            let paths = AgentSetupEngine.paths(for: .opencode, prefix: prefix, home: prefix)
            let alias = try #require(paths.alias)
            try FileManager.default.removeItem(at: alias)
            try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: "something-else")

            let report = AgentSetupEngine.verify(.opencode, prefix: prefix, home: prefix)
            let aliasItem = try #require(report.items.first { $0.id == "alias" })
            #expect(aliasItem.status == .fail)
            #expect(aliasItem.detail.contains("expected opencode"))
        }
    }

    @Test func resetItemsReflectExistingState() throws {
        try withTempHome { prefix in
            let beforeSetup = AgentSetupEngine.resetItems(for: [.antigravity], prefix: prefix, home: prefix)
            #expect(beforeSetup.allSatisfy { !$0.exists })

            try AgentSetupEngine.setup(.antigravity, prefix: prefix, home: prefix)
            let afterSetup = AgentSetupEngine.resetItems(for: [.antigravity], prefix: prefix, home: prefix)
            #expect(afterSetup.allSatisfy { $0.exists })
        }
    }

    @Test func resetRemovesEverythingSetupCreated() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.antigravity, prefix: prefix, home: prefix)
            try AgentSetupEngine.reset([.antigravity], prefix: prefix, home: prefix)

            let report = AgentSetupEngine.check(.antigravity, prefix: prefix, home: prefix)
            #expect(report.failCount == report.items.count)
        }
    }

    @Test func uninstallRemovesEverythingSetupCreated() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.grok, prefix: prefix, home: prefix)
            try AgentSetupEngine.uninstall(.grok, prefix: prefix, home: prefix)

            let paths = AgentSetupEngine.paths(for: .grok, prefix: prefix, home: prefix)
            #expect(!FileManager.default.fileExists(atPath: paths.wrapper.path))
            #expect(!FileManager.default.fileExists(atPath: paths.configDir.path))
            #expect(!FileManager.default.fileExists(atPath: paths.dataDir.path))
        }
    }

    @Test func sandboxInstallWritesProfileWrapperAndLink() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.claude, prefix: prefix, home: prefix)
            try AgentSetupEngine.sandboxInstall(.claude, prefix: prefix, home: prefix)

            let status = AgentSetupEngine.sandboxStatus(.claude, prefix: prefix, home: prefix)
            #expect(status.isInstalled)
            #expect(status.linked)
            #expect(status.rules.contains { $0.contains("deny default") })
        }
    }

    @Test func sandboxUninstallRemovesProfileAndLink() throws {
        try withTempHome { prefix in
            try AgentSetupEngine.setup(.claude, prefix: prefix, home: prefix)
            try AgentSetupEngine.sandboxInstall(.claude, prefix: prefix, home: prefix)
            try AgentSetupEngine.sandboxUninstall(.claude, prefix: prefix, home: prefix)

            let status = AgentSetupEngine.sandboxStatus(.claude, prefix: prefix, home: prefix)
            #expect(!status.profileExists)
            #expect(!status.linked)
        }
    }

    @Test func everyTargetHasAUniqueCommandAndEnvPrefix() {
        let commands = AgentSetupTarget.allCases.map(\.command)
        #expect(Set(commands).count == commands.count)
        let envPrefixes = AgentSetupTarget.allCases.map(\.envPrefix)
        #expect(Set(envPrefixes).count == envPrefixes.count)
    }
}
#endif
