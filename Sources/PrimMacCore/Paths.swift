import Foundation

public enum Paths {
    public static func home() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    public static func registry() -> URL {
        if let env = ProcessInfo.processInfo.environment["PRIM_REGISTRY"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return home().appendingPathComponent("repos-eidos-agi/prim/registry/registry.json")
    }

    /// Machine-local Prim Tools overlay (connectors that only exist on this Mac).
    /// Merged by `Registry.load`. Override with `PRIM_LOCAL_REGISTRY`.
    public static func localRegistry() -> URL {
        if let env = ProcessInfo.processInfo.environment["PRIM_LOCAL_REGISTRY"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return home().appendingPathComponent(".prim/registry.local.json")
    }

    /// Web tool assets (editors, frames). Override with `PRIM_WEB`.
    public static func toolsRoot() -> URL {
        if let env = ProcessInfo.processInfo.environment["PRIM_WEB"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return home().appendingPathComponent("repos-eidos-agi/prim-web/demo")
    }

    /// Sample `.prim` packs for HostTests and local open proofs.
    public static func samples() -> URL {
        home().appendingPathComponent("repos-eidos-agi/prim-web/demo")
    }

    /// Shipped ASMP manifest. Override with `PRIM_ASMP_YAML`.
    public static func asmpYAML() -> URL {
        if let env = ProcessInfo.processInfo.environment["PRIM_ASMP_YAML"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return home().appendingPathComponent("repos-eidos-agi/prims-desktop/asmp.yaml")
    }

    /// Durable debug day files. Override with `PRIM_DEBUG_LOG_DIR` (tests).
    /// Never rotate or delete; each calendar day is a new file.
    public static func debugLogs() -> URL {
        if let env = ProcessInfo.processInfo.environment["PRIM_DEBUG_LOG_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return home().appendingPathComponent("Library/Logs/Prims Desktop")
    }
}
