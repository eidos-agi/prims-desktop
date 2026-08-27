import Foundation
import PrimMacCore
import PrimSimCore
import XCTest

final class HostTests: XCTestCase {
    func testEverySampleHasACitingSurface() throws {
        let catalog = try HostCatalog.load()
        let dir = Paths.samples()
        let packs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "prim" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        // 15 packs in prim-web/demo today; scene/study/video have no surface/sample yet (Prim product).
        let pendingSurfaces: Set<String> = ["scene", "study", "video"]
        // Surfaces exist; demo tree has no sample packs yet.
        let pendingSamples: Set<String> = ["docs", "log"]
        XCTAssertGreaterThanOrEqual(packs.count, 15, "expected demo sample packs under Paths.samples()")
        var seen = Set<String>()
        for url in packs {
            let detected = try Detect.open(url)
            XCTAssertFalse(detected.kind.isEmpty, url.lastPathComponent)
            let surfaces = catalog.surfaces(citing: detected.kind)
            XCTAssertFalse(surfaces.isEmpty, "\(url.lastPathComponent) kind=\(detected.kind) has no surface tool")
            seen.insert(detected.kind)
        }
        let types = Set(catalog.registry.types.map(\.name))
        let missing = types.subtracting(seen).subtracting(pendingSurfaces).subtracting(pendingSamples)
        XCTAssertEqual(missing, [], "registry types without a sample pack: \(missing.sorted())")
    }

    func testNewPackDetectsEveryRegistryType() throws {
        let catalog = try HostCatalog.load()
        // Product gaps Prim tracks — no surface tools yet. Do not fake host pairing.
        let pendingSurfaces: Set<String> = ["scene", "study", "video"]
        // Surfaces exist; demo tree has no sample packs yet.
        let pendingSamples: Set<String> = ["docs", "log"]
        for type in catalog.registry.types {
            let data = try PackNew.make(kind: type.name)
            let detected = try PackNew.inspect(data)
            XCTAssertEqual(detected.kind, type.name, type.name)
            if pendingSurfaces.contains(type.name) { continue }
            XCTAssertFalse(catalog.surfaces(citing: type.name).isEmpty, type.name)
        }
    }

    func testSaveAsKeepsKind() throws {
        let src = Paths.samples().appendingPathComponent("intent.emf.prim")
        let data = try Data(contentsOf: src)
        let before = try PackNew.inspect(data)
        XCTAssertEqual(before.kind, "emf")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("prim-saveas-\(UUID().uuidString).prim")
        try data.write(to: dest)
        defer { try? FileManager.default.removeItem(at: dest) }
        let after = try Detect.open(dest)
        XCTAssertEqual(after.kind, "emf")
    }

    func testExportMutationStaysTheKind() throws {
        let data = try PackNew.make(kind: "session")
        let turn = #"{"id":"T-01","who":"human","at":"00:01","text":"Logged from the host."}"# + "\n"
        let next = try PackExport.mutating(data, file: "turns.jsonl", turn)
        let detected = try PackNew.inspect(next)
        XCTAssertEqual(detected.kind, "session")
        let text = try PackExport.file(next, named: "turns.jsonl")
        XCTAssertTrue(text.contains("Logged from the host."))
    }

    func testOpeningObifHostsTheEditor() throws {
        let catalog = try HostCatalog.load()
        let url = Paths.samples().appendingPathComponent("mark.obif.prim")
        let detected = try Detect.open(url)
        XCTAssertEqual(detected.kind, "obif")
        let hosted = HostUI.hostedSurface(named: "", kind: detected.kind, catalog: catalog)
        XCTAssertEqual(hosted?.name, "obif-editor")
        if let hosted {
            XCTAssertTrue(HostUI.embedsInWeb(hosted))
        }
        XCTAssertEqual(
            HostUI.hostedSurface(named: "obif-editor", kind: "obif", catalog: catalog)?.name,
            "obif-editor"
        )
        let sim = catalog.registry.tool(named: "prim-sim")
        XCTAssertNotNil(sim)
        XCTAssertNil(HostUI.hostedSurface(named: sim!.name, kind: "obif", catalog: catalog))
    }

    func testHostIsTheWay() throws {
        let catalog = try HostCatalog.load()
        let host = catalog.registry.tool(named: "prim-mac")
        XCTAssertEqual(host?.kind, "surface")
        XCTAssertEqual(host?.cites, "*")
        XCTAssertEqual(host?.as, "host")
        XCTAssertEqual(host?.bin, "Prim")
        XCTAssertFalse(
            catalog.surfaces(citing: "emf").contains { $0.name == "prim-mac" },
            "the host cites *; it is not a type-specific picker tool"
        )
    }

    func testRegistryListsConnectors() throws {
        let catalog = try HostCatalog.load()
        XCTAssertFalse(catalog.connectors().isEmpty, "registry has no local connectors")
        let docket = catalog.connectors(citing: "docket")
        XCTAssertEqual(docket.map(\.name), ["docket-webmcp"])
        XCTAssertEqual(HostUI.room(for: docket[0]), "seal")
        XCTAssertTrue(HostUI.embedsInWeb(docket[0]))
        XCTAssertFalse(catalog.citing("docket").contains { $0.as == "host" })
        let sim = catalog.registry.tool(named: "prim-sim")
        XCTAssertNotNil(sim)
        XCTAssertTrue(HostUI.isProcess(sim!))
        XCTAssertFalse(HostUI.embedsInWeb(sim!))
        XCTAssertEqual(catalog.listed().count, catalog.registry.tools.count - catalog.hosts().count)
        let chatdb = catalog.registry.tool(named: "imessage-chatdb-receive")
        XCTAssertNotNil(chatdb, "local overlay should list imessage-chatdb-receive")
        XCTAssertEqual(chatdb?.kind, "connector")
        XCTAssertEqual(chatdb?.direction, "receive")
        XCTAssertEqual(chatdb?.cites, "*")
        XCTAssertEqual(chatdb?.as, "chatdb-sqlite")
        XCTAssertEqual(chatdb?.bin, "imessage-chatdb-receive")
        XCTAssertTrue(HostUI.isInHost(chatdb!))
        XCTAssertFalse(HostUI.isProcess(chatdb!))
        XCTAssertFalse(HostUI.embedsInWeb(chatdb!))
        XCTAssertTrue(HostUI.cites(chatdb!, kind: ""))
        XCTAssertTrue(HostUI.cites(chatdb!, kind: "session"))
        XCTAssertTrue(catalog.connectors().contains { $0.name == "imessage-chatdb-receive" })
        XCTAssertTrue(catalog.connectors().contains { $0.name == "opff-dally-receive" })
    }

    func testStarCiteDoesNotMintPackTypes() {
        let tool = PrimTool(
            name: "imessage-chatdb-receive",
            kind: "connector",
            direction: "receive",
            cites: "*",
            as: "chatdb-sqlite",
            bin: "imessage-chatdb-receive",
            repo: "local"
        )
        XCTAssertTrue(HostUI.isInHost(tool))
        XCTAssertFalse(HostUI.isProcess(tool))
        XCTAssertTrue(HostUI.cites(tool, kind: "emf"))
        XCTAssertFalse(HostUI.embedsInWeb(tool))
    }

    func testNoMintedToolTypes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let walker = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)!
        for case let file as URL in walker where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("prim.surface"), file.lastPathComponent)
            XCTAssertFalse(text.contains("prim.connector"), file.lastPathComponent)
        }
    }

    func testPreferredConnectorIsIMessage() throws {
        let catalog = try HostCatalog.load()
        let pick = HostUI.preferredConnector(catalog.registry.tools)
        XCTAssertEqual(pick?.name, "imessage-chatdb-receive")
        XCTAssertEqual(HostUI.accountConnectors(catalog.registry.tools).first?.name, "imessage-chatdb-receive")
        XCTAssertTrue(HostUI.isInHost(pick!))
        XCTAssertFalse(HostUI.isProcess(pick!))
    }

    func testCLIConnectorsListsMergedOverlay() throws {
        let result = DesktopCLI.invoke(["connectors", "--json"])
        XCTAssertEqual(result.status, 0, result.stderr)
        let data = try XCTUnwrap(result.stdout.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try XCTUnwrap(obj["connectors"] as? [[String: Any]])
        let names = rows.compactMap { $0["name"] as? String }
        XCTAssertTrue(names.contains("imessage-chatdb-receive"))
        XCTAssertTrue(names.contains("opff-dally-receive"))
        let imessage = try XCTUnwrap(rows.first { ($0["name"] as? String) == "imessage-chatdb-receive" })
        XCTAssertEqual(imessage["kind"] as? String, "connector")
        XCTAssertEqual(imessage["direction"] as? String, "receive")
        XCTAssertEqual(imessage["as"] as? String, "chatdb-sqlite")
        XCTAssertEqual(imessage["cites"] as? String, "*")
        XCTAssertEqual(imessage["bin"] as? String, "imessage-chatdb-receive")
        XCTAssertEqual(imessage["in_host"] as? Bool, true)
    }

    func testCLIConfigSetPreservesOpff() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("prim-cli-overlay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let overlay = tmp.appendingPathComponent("registry.local.json")
        let seed = RegistryDoc(
            version: 1,
            types: [],
            tools: [
                PrimTool(
                    name: "opff-dally-receive",
                    kind: "connector",
                    direction: "receive",
                    cites: "opff",
                    as: "dally-sqlite",
                    bin: "opff-dally-receive",
                    repo: "local"
                ),
                PrimTool(
                    name: "imessage-chatdb-receive",
                    kind: "connector",
                    direction: "receive",
                    cites: "*",
                    as: "chatdb-sqlite",
                    bin: "imessage-chatdb-receive",
                    repo: "local"
                ),
            ]
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(seed).write(to: overlay)

        setenv("PRIM_LOCAL_REGISTRY", overlay.path, 1)
        defer { unsetenv("PRIM_LOCAL_REGISTRY") }

        let result = DesktopCLI.invoke(["config", "set", "imessage-chatdb-receive", "bin", "imessage-chatdb-receive"])
        XCTAssertEqual(result.status, 0, result.stderr)
        let local = try LocalOverlay.load()
        XCTAssertNotNil(local.tool(named: "opff-dally-receive"), "config set must not wipe opff-dally-receive")
        XCTAssertEqual(local.tool(named: "opff-dally-receive")?.as, "dally-sqlite")
        XCTAssertEqual(local.tool(named: "imessage-chatdb-receive")?.bin, "imessage-chatdb-receive")
    }

    func testCLIReceiveUnknownConnectorFails() {
        let result = DesktopCLI.invoke(["receive", "not-a-connector", "--limit", "3"])
        XCTAssertEqual(result.status, 1)
        XCTAssertTrue(result.stderr.contains("no connector named not-a-connector"), result.stderr)
    }

    func testCLIReceiveRejectsNonIMessageConnector() {
        let result = DesktopCLI.invoke(["receive", "opff-dally-receive", "--limit", "3"])
        XCTAssertEqual(result.status, 1)
        XCTAssertTrue(result.stderr.contains("only imessage-chatdb-receive"), result.stderr)
    }
}
