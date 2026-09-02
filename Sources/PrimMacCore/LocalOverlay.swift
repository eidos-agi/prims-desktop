import Foundation
import PrimSimCore

/// Read/write `~/.prim/registry.local.json` without dropping sibling tools.
public enum LocalOverlay {
    public static func url() -> URL {
        Paths.localRegistry()
    }

    public static func load() throws -> RegistryDoc {
        let path = url()
        guard FileManager.default.fileExists(atPath: path.path) else {
            return RegistryDoc(version: 1, types: [], tools: [])
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(RegistryDoc.self, from: data)
    }

    public static func save(_ doc: RegistryDoc) throws {
        var next = doc
        if next.version == 0 { next.version = 1 }
        next.tools.sort { $0.name < $1.name }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(next)
        guard let typed = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw OverlayError("overlay encode failed")
        }
        var raw = (try? loadRaw()) ?? [:]
        for (key, value) in typed {
            raw[key] = value
        }
        try writeRaw(raw)
    }

    /// Overlay JSON including extra keys (paseo tenant catalog). Same file.
    public static func loadRaw() throws -> [String: Any] {
        let path = url()
        guard FileManager.default.fileExists(atPath: path.path) else { return [:] }
        let data = try Data(contentsOf: path)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OverlayError("overlay is not a JSON object")
        }
        return obj
    }

    public static func mergeRaw(_ extra: [String: Any]) throws {
        var raw = try loadRaw()
        for (key, value) in extra {
            raw[key] = value
        }
        if raw["version"] == nil { raw["version"] = 1 }
        if raw["types"] == nil { raw["types"] = [Any]() }
        if raw["tools"] == nil { raw["tools"] = [Any]() }
        try writeRaw(raw)
    }

    private static func writeRaw(_ raw: [String: Any]) throws {
        let path = url()
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys])
        var out = data
        out.append(contentsOf: "\n".utf8)
        try out.write(to: path, options: .atomic)
    }

    /// Update one overlay tool field. Other overlay tools (including
    /// `opff-dally-receive`) stay. Unknown public tools are copied into
    /// the overlay first so local wins on merge.
    public static func setField(tool name: String, field: String, value: String, catalog: RegistryDoc) throws -> PrimTool {
        var local = try load()
        guard var tool = local.tool(named: name) ?? catalog.tool(named: name) else {
            throw OverlayError("no tool named \(name) in overlay or registry")
        }
        switch field {
        case "as":
            tool.as = value
        case "bin":
            tool.bin = value
        case "cites":
            tool.cites = value
        case "direction":
            tool.direction = value
        case "kind":
            tool.kind = value
        case "repo":
            tool.repo = value
        default:
            throw OverlayError("unknown field \(field) (as, bin, cites, direction, kind, repo)")
        }
        var tools = local.tools.filter { $0.name != name }
        tools.append(tool)
        local.tools = tools
        try save(local)
        return tool
    }

    public struct OverlayError: Error, LocalizedError {
        public var message: String
        public init(_ message: String) { self.message = message }
        public var errorDescription: String? { message }
    }
}
