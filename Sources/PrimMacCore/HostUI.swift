import Foundation
import PrimSimCore

/// How the host opens a registered tool. Category `ui` is a view key;
/// this is the host pairing: room, web embed, or local process.
public enum HostUI: Sendable {
    public static func listed(_ tools: [PrimTool]) -> [PrimTool] {
        tools.filter { $0.as != "host" }
    }

    public static func hosts(_ tools: [PrimTool]) -> [PrimTool] {
        tools.filter { $0.as == "host" }
    }

    public static func surfaces(_ tools: [PrimTool]) -> [PrimTool] {
        listed(tools).filter { $0.kind == "surface" }
    }

    public static func connectors(_ tools: [PrimTool]) -> [PrimTool] {
        listed(tools).filter { $0.kind == "connector" }
    }

    /// Rail order: the in-host iMessage account first, then the rest by name.
    public static func accountConnectors(_ tools: [PrimTool]) -> [PrimTool] {
        connectors(tools).sorted { a, b in
            if isInHost(a) != isInHost(b) { return isInHost(a) }
            return a.name < b.name
        }
    }

    /// First launch / empty selection lands on iMessage when it exists.
    public static func preferredConnector(_ tools: [PrimTool]) -> PrimTool? {
        accountConnectors(tools).first
    }

    public static func room(for tool: PrimTool) -> String {
        if tool.as == "webmcp" || tool.name == "docket-webmcp" { return "seal" }
        if tool.as == "arcade" || tool.name == "prim-arcade" { return "arcade" }
        if tool.name.hasSuffix("-editor") { return tool.cites }
        return tool.cites
    }

    public static func embedsInWeb(_ tool: PrimTool) -> Bool {
        guard tool.as != "host" else { return false }
        if tool.as == "sim" { return false }
        if tool.kind == "connector" { return tool.as == "webmcp" }
        return tool.kind == "surface"
    }

    public static func isProcess(_ tool: PrimTool) -> Bool {
        if isInHost(tool) { return false }
        return tool.as == "sim" || (tool.bin != nil && tool.as != "host" && !embedsInWeb(tool))
    }

    /// Connector the signed host runs itself (chat.db). Not a spawned helper.
    public static func isInHost(_ tool: PrimTool) -> Bool {
        tool.as == "chatdb-sqlite" || tool.name == "imessage-chatdb-receive"
    }

    /// `*` cites every open pack (and the empty document). Do not seed a type for it.
    public static func cites(_ tool: PrimTool, kind: String) -> Bool {
        tool.cites == "*" || kind.isEmpty || tool.cites == kind
    }

    /// Surface the host should embed for this pack. Empty toolName still
    /// hosts the citing editor — onAppear must not be the only path.
    public static func hostedSurface(named: String, kind: String, catalog: HostCatalog) -> PrimTool? {
        if !named.isEmpty, let tool = catalog.registry.tool(named: named) {
            if embedsInWeb(tool) { return tool }
            if isProcess(tool) || isInHost(tool) { return nil }
        }
        guard !kind.isEmpty else { return nil }
        if let pick = catalog.defaultTool(citing: kind), embedsInWeb(pick) { return pick }
        return catalog.surfaces(citing: kind).first
    }
}
