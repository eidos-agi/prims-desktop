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
        XCTAssertTrue(catalog.connectors().contains { $0.name == Paseo.connectorName })
        XCTAssertFalse(catalog.connectors().contains { HostUI.isViewer($0) })
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

    func testASMPLiveCapsFollowHostCatalog() throws {
        let catalog = try HostCatalog.load()
        let connectors = HostUI.connectors(catalog.registry.tools)
        let names = Set(connectors.map(\.name))
        XCTAssertTrue(names.contains("imessage-chatdb-receive"))
        XCTAssertTrue(names.contains("opff-dally-receive"))
        let caps = ASMP.liveCapabilities(connectors: connectors)
        XCTAssertTrue(caps.contains("prims-desktop.host"))
        XCTAssertTrue(caps.contains("prims-desktop.cli"))
        XCTAssertTrue(names.contains(Paseo.connectorName))
        XCTAssertFalse(names.contains("prim-viewer-webmcp"))
        XCTAssertFalse(names.contains("prim-viewer"))
        for name in names {
            XCTAssertTrue(caps.contains("connector.\(name)"), "missing connector.\(name)")
        }
        XCTAssertFalse(caps.contains("prim." + "connector"))
        XCTAssertFalse(caps.contains("prim." + "surface"))

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("prim-asmp-\(UUID().uuidString).yaml")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try ASMP.writeManifest(connectors: connectors, url: tmp)
        let yaml = try String(contentsOf: tmp, encoding: .utf8)
        XCTAssertTrue(yaml.contains("connector.imessage-chatdb-receive"))
        XCTAssertTrue(yaml.contains("connector.opff-dally-receive"))
        XCTAssertTrue(yaml.contains("http://127.0.0.1:7749/health"))
        XCTAssertFalse(yaml.contains("kind: " + "prim.connector"))
    }

    func testASMPConnectorManifestIsAServiceNotAPackType() {
        let tool = PrimTool(
            name: "imessage-chatdb-receive",
            kind: "connector",
            direction: "receive",
            cites: "*",
            as: "chatdb-sqlite",
            bin: "imessage-chatdb-receive",
            repo: "local"
        )
        let m = ASMP.connectorManifest(tool)
        XCTAssertEqual(m["kind"] as? String, "service")
        XCTAssertEqual(m["name"] as? String, "imessage-chatdb-receive")
        XCTAssertEqual(m["parent"] as? String, "prims-desktop")
        let caps = m["capabilities"] as? [String: Any]
        let provides = caps?["provides"] as? [String]
        XCTAssertEqual(provides, ["connector.imessage-chatdb-receive"])
    }

    func testProductIdentityIsLocked() {
        XCTAssertEqual(ProductIdentity.displayName, "Prims Desktop")
        XCTAssertEqual(ProductIdentity.bundleIdentifier, "sh.prims.desktop")
        XCTAssertEqual(ProductIdentity.packUTI, "com.eidosagi.prim")
        XCTAssertEqual(ProductIdentity.appPath, "/Applications/Prims Desktop.app")
        XCTAssertEqual(ProductIdentity.executableName, "Prim")
        XCTAssertEqual(
            ProductIdentity.fdaNote,
            "Prims Desktop needs Full Disk Access to read Messages on this Mac."
        )
        XCTAssertEqual(DesktopCLI.appURL().path, "/Applications/Prims Desktop.app")
        XCTAssertEqual(
            DesktopCLI.helperURL().path,
            "/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop"
        )
        XCTAssertEqual(DesktopCLI.fdaNote, ProductIdentity.fdaNote)
        XCTAssertEqual(ChatDB.fdaNote, ProductIdentity.fdaNote)
        XCTAssertFalse(ProductIdentity.fdaNote.contains("~/.local/bin"))
        XCTAssertFalse(DesktopCLI.fdaNote.contains("~/.local/bin"))
        XCTAssertFalse(ChatDB.fdaNote.contains("~/.local/bin"))
        XCTAssertNotEqual(ProductIdentity.bundleIdentifier, ProductIdentity.packUTI)
    }

    func testInfoPlistAndPPPCAreBound() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plist = try String(contentsOf: root.appendingPathComponent("Info.plist"), encoding: .utf8)
        XCTAssertTrue(plist.contains("<key>CFBundleIdentifier</key>"))
        XCTAssertTrue(plist.contains("<string>sh.prims.desktop</string>"))
        XCTAssertTrue(plist.contains("<string>com.eidosagi.prim</string>"))
        XCTAssertTrue(plist.contains("<string>prim</string>"))
        XCTAssertTrue(plist.contains("<string>Prims Desktop</string>"))
        let idSlice = plist.components(separatedBy: "<key>CFBundleIdentifier</key>")[1]
            .components(separatedBy: "<key>")[0]
        XCTAssertTrue(idSlice.contains("sh.prims.desktop"))
        XCTAssertFalse(idSlice.contains("com.eidosagi.prim"))

        let profile = try String(
            contentsOf: root.appendingPathComponent("deploy/prims-desktop.fulldisk.mobileconfig"),
            encoding: .utf8
        )
        XCTAssertTrue(profile.contains("<key>Identifier</key>"))
        XCTAssertTrue(profile.contains("<string>sh.prims.desktop</string>"))
        XCTAssertTrue(profile.contains("<key>IdentifierType</key>"))
        XCTAssertTrue(profile.contains("<string>bundleID</string>"))
        XCTAssertTrue(profile.contains("<key>SystemPolicyAllFiles</key>"))
        XCTAssertTrue(profile.contains("<key>Allowed</key>"))
        XCTAssertTrue(profile.contains("codesign -dr"))
        XCTAssertTrue(profile.contains("FILL_FROM_codesign"))
        XCTAssertFalse(profile.contains("anchor apple generic"))

        let trampoline = try String(
            contentsOf: root.appendingPathComponent("scripts/prims-desktop-trampoline.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(trampoline.contains("exec "))
        XCTAssertTrue(trampoline.contains("/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop"))
        XCTAssertFalse(trampoline.contains("chat.db"))
        XCTAssertFalse(trampoline.contains("ChatDB"))
        XCTAssertFalse(trampoline.contains("sqlite"))
    }

    func testSourcesDoNotAskFDAForLooseCLI() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let old = "Grant Full Disk Access to prims-desktop (~/.local/bin/prims-desktop)"
        let files = [
            "Sources/PrimMacCore/DesktopCLI.swift",
            "Sources/PrimMacCore/ChatDB.swift",
            "Sources/PrimMac/HostView.swift",
            "Sources/PrimMac/UI/StageView.swift",
            "tools/imessage-chatdb-receive.swift",
        ]
        for rel in files {
            let text = try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
            XCTAssertFalse(text.contains(old), rel)
            XCTAssertFalse(text.contains("The app CLI is a separate binary"), rel)
        }
    }

    func testViewerIsSurfaceNotDesktopConnector() {
        let viewer = PrimTool(
            name: "prim-viewer-webmcp",
            kind: "connector",
            direction: "view",
            cites: "*",
            as: "webmcp",
            bin: nil,
            repo: "prim-web"
        )
        XCTAssertTrue(HostUI.isViewer(viewer))
        XCTAssertTrue(HostUI.surfaces([viewer]).contains { $0.name == viewer.name })
        XCTAssertFalse(HostUI.connectors([viewer]).contains { $0.name == viewer.name })
    }

    func testPaseoRegistrySeedsSevenCellsAndOneConnector() throws {
        try withPaseoOverlay {
            let tenants = try Paseo.ensureSeeded()
            XCTAssertEqual(Set(tenants.map(\.id)), Set(Paseo.seedTenants.map(\.id)))
            XCTAssertEqual(tenants.count, 7)
            let local = try LocalOverlay.load()
            XCTAssertNotNil(local.tool(named: Paseo.connectorName))
            XCTAssertEqual(local.tools.filter { $0.name.hasPrefix("paseo") || $0.as == "paseo" }.count, 1)

            let cells = DesktopCLI.invoke(["cells", "--json"])
            XCTAssertEqual(cells.status, 0, cells.stderr)
            let obj = try jsonObject(cells.stdout)
            XCTAssertEqual(obj["connector"] as? String, Paseo.connectorName)
            let rows = try XCTUnwrap(obj["cells"] as? [[String: Any]])
            XCTAssertEqual(rows.count, 7)
            XCTAssertTrue(rows.contains { ($0["id"] as? String) == "paseo-gmw" && ($0["port"] as? Int) == 16768 })
            XCTAssertTrue(rows.contains { ($0["id"] as? String) == "laptop" && ($0["reach"] as? String) == "local" })
        }
    }

    func testPaseoCellsAddIsARowNotAConnector() throws {
        try withPaseoOverlay {
            _ = try Paseo.ensureSeeded()
            let added = DesktopCLI.invoke([
                "cells", "add", "paseo-demo",
                "--host", "127.0.0.1",
                "--port", "16780",
                "--reach", "ssh",
                "--ssh", "hostkey",
                "--notes", "new cell",
                "--json",
            ])
            XCTAssertEqual(added.status, 0, added.stderr)
            let tenants = try Paseo.loadTenants()
            XCTAssertEqual(tenants.count, 8)
            XCTAssertTrue(tenants.contains { $0.id == "paseo-demo" && $0.port == 16780 && $0.reach == .ssh })
            let local = try LocalOverlay.load()
            XCTAssertEqual(local.tools.filter { Paseo.isPaseo($0) }.count, 1)
        }
    }

    func testPaseoV1VerbsAreStructuralAndSendNeedsNoWait() throws {
        try withPaseoOverlay {
            _ = try Paseo.ensureSeeded()
            var calls: [[String]] = []
            var hops: [String] = []
            Paseo.execHook = { argv in
                calls.append(argv)
                return Paseo.ExecResult(status: 0, stdout: #"{"ok":true}"#, stderr: "", argv: argv, host: argv[4], tunneled: argv[4].contains("26768"))
            }
            Paseo.tunnelHook = { tenant in
                hops.append("\(tenant.id):\(tenant.localForwardPort):\(tenant.ssh)")
            }

            let blocked = DesktopCLI.invoke(["send", "paseo-gmw", Paseo.proveAgent, "hi", "--json"])
            XCTAssertEqual(blocked.status, 1)
            XCTAssertTrue(blocked.stdout.contains("no-wait") || blocked.stderr.contains("no-wait"))
            XCTAssertTrue(calls.isEmpty, "send must not fire without --no-wait")

            let inspect = DesktopCLI.invoke(["inspect", "paseo-gmw", Paseo.proveAgent, "--json"])
            XCTAssertEqual(inspect.status, 0, inspect.stderr)
            let inspectObj = try jsonObject(inspect.stdout)
            XCTAssertEqual(inspectObj["tenant"] as? String, "paseo-gmw")
            XCTAssertEqual(inspectObj["tunneled"] as? Bool, true)
            XCTAssertEqual(inspectObj["host"] as? String, "127.0.0.1:26768")
            XCTAssertEqual(hops, ["paseo-gmw:26768:hostkey"])

            let laptop = DesktopCLI.invoke(["ls", "laptop", "--json"])
            XCTAssertEqual(laptop.status, 0, laptop.stderr)
            let laptopObj = try jsonObject(laptop.stdout)
            XCTAssertEqual(laptopObj["tunneled"] as? Bool, false)
            XCTAssertEqual(laptopObj["host"] as? String, "127.0.0.1:6767")

            let health = DesktopCLI.invoke(["health", "paseo-gmw", "--json"])
            XCTAssertEqual(health.status, 0, health.stderr)
            let logs = DesktopCLI.invoke(["logs", "laptop", "--json"])
            XCTAssertEqual(logs.status, 0, logs.stderr)
            let follow = DesktopCLI.invoke(["logs", "laptop", "--follow", "--json"])
            XCTAssertEqual(follow.status, 1)
            XCTAssertTrue((follow.stdout + follow.stderr).contains("follow"))

            let send = DesktopCLI.invoke(["send", "paseo-gmw", Paseo.proveAgent, "--no-wait", "later", "--json"])
            XCTAssertEqual(send.status, 0, send.stderr)
            XCTAssertTrue(calls.contains { $0.contains("inspect") && $0.contains(Paseo.proveAgent) })
            XCTAssertTrue(calls.contains { $0.contains("send") && $0.contains("--no-wait") })
            XCTAssertFalse(calls.contains { $0.contains("--follow") })

            let denied = DesktopCLI.invoke(["run", "paseo-gmw", "--json"])
            XCTAssertEqual(denied.status, 1)
            XCTAssertTrue((denied.stdout + denied.stderr).contains("out of v1"))
        }
    }

    func testPaseoASMPManifestIsNotHostHealth() {
        let m = ASMP.connectorManifest(Paseo.connectorTool)
        XCTAssertEqual(m["name"] as? String, Paseo.connectorName)
        XCTAssertEqual(m["kind"] as? String, "service")
        XCTAssertEqual(m["parent"] as? String, "prims-desktop")
        let endpoints = m["endpoints"] as? [[String: Any]] ?? []
        XCTAssertFalse(endpoints.contains { ($0["protocol"] as? String) == "http" && ($0["port"] as? Int) == 7749 })
        let health = m["health"] as? [String: Any]
        XCTAssertEqual(health?["method"] as? String, "cli")
        let target = (health?["target"] as? String) ?? ""
        XCTAssertFalse(target.contains("7749"))
        XCTAssertTrue(target.contains(Paseo.connectorName))
        XCTAssertFalse(ASMP.capability(for: Paseo.connectorTool).contains("prim-viewer"))
    }

    func testPaseoStatusDoesNotLieWhenDark() throws {
        try withPaseoOverlay {
            _ = try Paseo.ensureSeeded()
            Paseo.execHook = { argv in
                Paseo.ExecResult(status: 1, stdout: "", stderr: "down", argv: argv, host: argv[4], tunneled: true)
            }
            Paseo.tunnelHook = { _ in }
            let result = DesktopCLI.invoke(["status", Paseo.connectorName, "--json"])
            XCTAssertEqual(result.status, 2)
            let obj = try jsonObject(result.stdout)
            XCTAssertEqual(obj["ok"] as? Bool, false)
            XCTAssertEqual(obj["reached"] as? Bool, false)
            let dark = obj["tenants_dark"] as? [String] ?? []
            XCTAssertEqual(Set(dark), Set(Paseo.seedTenants.map(\.id)))
        }
    }

    func testConfigSetPreservesPaseoTenants() throws {
        try withPaseoOverlay {
            _ = try Paseo.ensureSeeded()
            let before = try Paseo.loadTenants()
            XCTAssertEqual(before.count, 7)
            let catalog = RegistryDoc(
                version: 1,
                types: [],
                tools: [Paseo.connectorTool]
            )
            _ = try LocalOverlay.setField(
                tool: Paseo.connectorName,
                field: "bin",
                value: "paseo",
                catalog: catalog
            )
            let after = try Paseo.loadTenants()
            XCTAssertEqual(Set(after.map(\.id)), Set(before.map(\.id)))
            XCTAssertNotNil(try LocalOverlay.load().tool(named: "prims-connectors-paseo"))
        }
    }

    private func withPaseoOverlay(_ body: () throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("prim-paseo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        setenv("PRIM_LOCAL_REGISTRY", tmp.appendingPathComponent("registry.local.json").path, 1)
        defer { unsetenv("PRIM_LOCAL_REGISTRY") }
        Paseo.resetTestHooks()
        defer { Paseo.resetTestHooks() }
        try body()
    }

    private func jsonObject(_ text: String) throws -> [String: Any] {
        let data = try XCTUnwrap(text.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
