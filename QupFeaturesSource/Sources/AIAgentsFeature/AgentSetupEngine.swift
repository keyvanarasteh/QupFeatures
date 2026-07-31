#if os(macOS)
import Foundation

/// Native reimplementation of `SETUP/<name>/{setup,check,verify,fresh}-cli.sh`
/// (sandbox support lives in `AgentSetupEngine+Sandbox.swift`). Every path
/// matches those scripts exactly (`~/.config/<cmd>`, `~/.local/share/<cmd>`,
/// `<prefix>/bin`), so a Mac that already ran the shell toolkit shows up here
/// as already installed, and a Mac set up from this page works identically
/// from the shell. Pure `FileManager` work — no `Process` invocation.
enum AgentSetupEngine {
    struct Paths {
        let binDir: URL
        let wrapper: URL
        let alias: URL?
        let configDir: URL
        let dataDir: URL
        let sandboxDir: URL
        let sandboxProfile: URL
        let sandboxWrapper: URL
        let sandboxBinLink: URL
    }

    static var defaultPrefix: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local", isDirectory: true)
    }

    static func paths(
        for target: AgentSetupTarget,
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Paths {
        let binDir = prefix.appendingPathComponent("bin", isDirectory: true)
        let sandboxDir = home.appendingPathComponent(".sandbox/\(target.command)", isDirectory: true)
        return Paths(
            binDir: binDir,
            wrapper: binDir.appendingPathComponent(target.command),
            alias: target.alias.map { binDir.appendingPathComponent($0) },
            configDir: home.appendingPathComponent(".config/\(target.command)", isDirectory: true),
            dataDir: home.appendingPathComponent(".local/share/\(target.command)", isDirectory: true),
            sandboxDir: sandboxDir,
            sandboxProfile: sandboxDir.appendingPathComponent("\(target.command).sb"),
            sandboxWrapper: sandboxDir.appendingPathComponent(target.command),
            sandboxBinLink: binDir.appendingPathComponent("\(target.command)-sandbox")
        )
    }

    // MARK: - Setup / uninstall (setup-cli.sh)

    static func setup(
        _ target: AgentSetupTarget,
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        let fileManager = FileManager.default
        let paths = paths(for: target, prefix: prefix, home: home)
        do {
            try fileManager.createDirectory(at: paths.binDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: paths.configDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: paths.dataDir, withIntermediateDirectories: true)

            let wrapperScript = """
            #!/usr/bin/env bash
            # \(target.displayName) CLI wrapper — installed by Cupertino's Agent CLI Setup page
            export \(target.envPrefix)_CONFIG_DIR="\(paths.configDir.path)"
            export \(target.envPrefix)_DATA_DIR="\(paths.dataDir.path)"
            echo "\(target.displayName) (\(target.command)) — config: \(paths.configDir.path)  data: \(paths.dataDir.path)"
            exec "$@"

            """
            try replaceItem(at: paths.wrapper, with: wrapperScript)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: paths.wrapper.path)

            if let alias = paths.alias {
                removeIfPresent(alias)
                try fileManager.createSymbolicLink(atPath: alias.path, withDestinationPath: target.command)
            }
        } catch {
            throw AgentSetupError.filesystem(error.localizedDescription)
        }
    }

    static func uninstall(
        _ target: AgentSetupTarget,
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        let fileManager = FileManager.default
        let paths = paths(for: target, prefix: prefix, home: home)
        do {
            for url in [paths.wrapper, paths.alias].compactMap({ $0 }) { removeIfPresent(url) }
            for dir in [paths.configDir, paths.dataDir] where fileManager.fileExists(atPath: dir.path) {
                try fileManager.removeItem(at: dir)
            }
        } catch {
            throw AgentSetupError.filesystem(error.localizedDescription)
        }
    }

    // MARK: - Check (check-cli.sh)

    static func check(
        _ target: AgentSetupTarget,
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> AgentCheckReport {
        let paths = paths(for: target, prefix: prefix, home: home)
        var items: [AgentCheckItem] = [wrapperItem(paths: paths)]
        if let aliasItem = aliasItem(target: target, paths: paths) { items.append(aliasItem) }
        items.append(directoryItem(id: "config", title: "Config directory", url: paths.configDir))
        items.append(directoryItem(id: "data", title: "Data directory", url: paths.dataDir))
        return AgentCheckReport(items: items)
    }

    // MARK: - Verify (verify-cli.sh)

    static func verify(
        _ target: AgentSetupTarget,
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> AgentCheckReport {
        let fileManager = FileManager.default
        let paths = paths(for: target, prefix: prefix, home: home)
        var items: [AgentCheckItem] = []

        let wrapper = wrapperItem(paths: paths)
        items.append(wrapper)
        if wrapper.status == .pass, let contents = try? String(contentsOf: paths.wrapper, encoding: .utf8) {
            items.append(contentsOf: wrapperContentChecks(target: target, paths: paths, contents: contents))
        }

        if let aliasItem = aliasItem(target: target, paths: paths) { items.append(aliasItem) }

        let directories = [
            ("config", "Config directory", paths.configDir),
            ("data", "Data directory", paths.dataDir)
        ]
        for (id, title, url) in directories {
            if fileManager.fileExists(atPath: url.path) {
                let mode = posixModeString(at: url)
                items.append(AgentCheckItem(id: id, title: title, status: .pass, detail: "\(url.path) (mode \(mode))"))
            } else {
                items.append(AgentCheckItem(id: id, title: title, status: .fail, detail: "not found at \(url.path)"))
            }
        }

        return AgentCheckReport(items: items)
    }

    private static func wrapperContentChecks(
        target: AgentSetupTarget,
        paths: Paths,
        contents: String
    ) -> [AgentCheckItem] {
        let shebangOK = contents.hasPrefix("#!/usr/bin/env bash")
        let configVar = "\(target.envPrefix)_CONFIG_DIR"
        let dataVar = "\(target.envPrefix)_DATA_DIR"
        return [
            AgentCheckItem(
                id: "shebang", title: "Wrapper shebang",
                status: shebangOK ? .pass : .fail,
                detail: shebangOK ? "#!/usr/bin/env bash" : "missing or invalid shebang"
            ),
            AgentCheckItem(
                id: "config-var", title: "\(configVar) export",
                status: contents.contains(configVar) ? .pass : .fail,
                detail: contents.contains(configVar) ? "set to \(paths.configDir.path)" : "not found in wrapper"
            ),
            AgentCheckItem(
                id: "data-var", title: "\(dataVar) export",
                status: contents.contains(dataVar) ? .pass : .fail,
                detail: contents.contains(dataVar) ? "set to \(paths.dataDir.path)" : "not found in wrapper"
            )
        ]
    }

    // MARK: - Fresh / reset (fresh-cli.sh)

    static func resetItems(
        for targets: [AgentSetupTarget],
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [AgentResetItem] {
        let fileManager = FileManager.default
        var items: [AgentResetItem] = []
        for target in targets {
            let paths = paths(for: target, prefix: prefix, home: home)
            items.append(AgentResetItem(
                kind: .wrapper, path: paths.wrapper.path, exists: fileManager.fileExists(atPath: paths.wrapper.path)
            ))
            if let alias = paths.alias {
                items.append(AgentResetItem(kind: .alias, path: alias.path, exists: exists(alias)))
            }
            items.append(AgentResetItem(
                kind: .config, path: paths.configDir.path, exists: fileManager.fileExists(atPath: paths.configDir.path)
            ))
            items.append(AgentResetItem(
                kind: .data, path: paths.dataDir.path, exists: fileManager.fileExists(atPath: paths.dataDir.path)
            ))
        }
        return items
    }

    /// Removes every existing item `resetItems(for:prefix:)` reported — the
    /// non-dry-run half of `fresh-cli.sh`.
    static func reset(
        _ targets: [AgentSetupTarget],
        prefix: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        let fileManager = FileManager.default
        do {
            for item in resetItems(for: targets, prefix: prefix, home: home) where item.exists {
                try fileManager.removeItem(atPath: item.path)
            }
        } catch {
            throw AgentSetupError.filesystem(error.localizedDescription)
        }
    }

    // MARK: - Shared helpers

    static func wrapperItem(paths: Paths) -> AgentCheckItem {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: paths.wrapper.path) else {
            return AgentCheckItem(id: "wrapper", title: "Wrapper binary", status: .fail, detail: "not found at \(paths.wrapper.path)")
        }
        guard fileManager.isExecutableFile(atPath: paths.wrapper.path) else {
            return AgentCheckItem(
                id: "wrapper", title: "Wrapper binary", status: .fail, detail: "not executable: \(paths.wrapper.path)"
            )
        }
        return AgentCheckItem(id: "wrapper", title: "Wrapper binary", status: .pass, detail: paths.wrapper.path)
    }

    static func aliasItem(target: AgentSetupTarget, paths: Paths) -> AgentCheckItem? {
        guard let alias = paths.alias, let aliasName = target.alias else { return nil }
        let title = "Alias symlink (\(aliasName))"
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: alias.path) else {
            return AgentCheckItem(id: "alias", title: title, status: .fail, detail: "not found at \(alias.path)")
        }
        if destination == target.command {
            return AgentCheckItem(id: "alias", title: title, status: .pass, detail: "\(alias.path) -> \(destination)")
        }
        return AgentCheckItem(
            id: "alias", title: title, status: .fail, detail: "points to \(destination), expected \(target.command)"
        )
    }

    private static func directoryItem(id: String, title: String, url: URL) -> AgentCheckItem {
        if FileManager.default.fileExists(atPath: url.path) {
            return AgentCheckItem(id: id, title: title, status: .pass, detail: url.path)
        }
        return AgentCheckItem(id: id, title: title, status: .fail, detail: "not found at \(url.path)")
    }

    static func posixModeString(at url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let posix = attributes[.posixPermissions] as? NSNumber else { return "?" }
        return String(posix.intValue & 0o777, radix: 8)
    }

    /// True for a real file/directory or a symlink (dangling or not) — unlike
    /// `FileManager.fileExists`, which follows symlinks and misses dangling ones.
    static func exists(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.path) || (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    static func removeIfPresent(_ url: URL) {
        guard exists(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func replaceItem(at url: URL, with contents: String) throws {
        removeIfPresent(url)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
