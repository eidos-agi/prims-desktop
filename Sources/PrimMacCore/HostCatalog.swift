import Foundation
import PrimSimCore

public struct HostCatalog: Sendable {
    public var registry: RegistryDoc
    public var detected: DetectedPrim?

    public init(registry: RegistryDoc, detected: DetectedPrim? = nil) {
        self.registry = registry
        self.detected = detected
    }

    public static func load() throws -> HostCatalog {
        try Paseo.ensureSeeded()
        return HostCatalog(registry: try Registry.load(from: Paths.registry()))
    }

    public func listed() -> [PrimTool] {
        HostUI.listed(registry.tools)
    }

    public func hosts() -> [PrimTool] {
        HostUI.hosts(registry.tools)
    }

    public func surfaces() -> [PrimTool] {
        HostUI.surfaces(registry.tools)
    }

    public func connectors() -> [PrimTool] {
        HostUI.connectors(registry.tools)
    }

    public func surfaces(citing kind: String) -> [PrimTool] {
        HostUI.surfaces(registry.toolsCiting(kind))
    }

    public func connectors(citing kind: String) -> [PrimTool] {
        HostUI.connectors(registry.toolsCiting(kind))
    }

    public func citing(_ kind: String) -> [PrimTool] {
        HostUI.listed(registry.toolsCiting(kind))
    }

    public func defaultTool(citing kind: String) -> PrimTool? {
        let list = citing(kind)
        return list.first { $0.name.hasSuffix("-editor") || $0.as == "editor" || $0.as == "ledger" || $0.as == "arcade" }
            ?? list.first { HostUI.embedsInWeb($0) }
            ?? list.first
    }
}
