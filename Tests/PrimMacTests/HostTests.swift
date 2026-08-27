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

    func testASMPLiveCapsFollowHostCatalog() throws {
        let catalog = try HostCatalog.load()
        let connectors = HostUI.connectors(catalog.registry.tools)
        let names = Set(connectors.map(\.name))
        XCTAssertTrue(names.contains("imessage-chatdb-receive"))
        XCTAssertTrue(names.contains("opff-dally-receive"))
        let caps = ASMP.liveCapabilities(connectors: connectors)
        XCTAssertTrue(caps.contains("prims-desktop.host"))
        XCTAssertTrue(caps.contains("prims-desktop.cli"))
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
            DesktopCLI.principalURL().path,
            "/Applications/Prims Desktop.app/Contents/MacOS/Prim"
        )
        XCTAssertEqual(
            ProductIdentity.executableURL().path,
            "/Applications/Prims Desktop.app/Contents/MacOS/Prim"
        )
        XCTAssertEqual(
            DesktopCLI.helperURL().path,
            "/Applications/Prims Desktop.app/Contents/Helpers/prims-desktop"
        )
        XCTAssertNotEqual(DesktopCLI.principalURL().path, DesktopCLI.helperURL().path)
        XCTAssertFalse(DesktopCLI.cliURL().path.contains("/Contents/Helpers/prims-desktop"))
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
        XCTAssertTrue(trampoline.contains("/Applications/Prims Desktop.app/Contents/MacOS/Prim"))
        XCTAssertFalse(trampoline.contains("Contents/Helpers/prims-desktop"))
        XCTAssertFalse(trampoline.contains("chat.db"))
        XCTAssertFalse(trampoline.contains("ChatDB"))
        XCTAssertFalse(trampoline.contains("sqlite"))
    }

    func testProcessEntryRoutesEveryDesktopCLIVerb() {
        XCTAssertEqual(
            DesktopCLI.commands,
            ["connectors", "status", "receive", "open", "doctor", "asmp", "config", "help"]
        )
        XCTAssertEqual(DesktopCLI.globalFlags, ["--json", "-h", "--help"])
        XCTAssertFalse(ProcessEntry.shouldRunCLI([]), "empty argv is the human glass")
        XCTAssertFalse(ProcessEntry.shouldRunCLI(["/tmp/note.prim"]))
        for verb in DesktopCLI.commands {
            XCTAssertTrue(ProcessEntry.shouldRunCLI([verb]), verb)
        }
        for flag in DesktopCLI.globalFlags {
            XCTAssertTrue(ProcessEntry.shouldRunCLI([flag]), flag)
        }
        XCTAssertTrue(ProcessEntry.shouldRunCLI(["config", "get"]), "do not forget config")
        XCTAssertTrue(ProcessEntry.shouldRunCLI(["--json", "doctor"]))
        XCTAssertFalse(ProcessEntry.shouldRunCLI(["--unknown-flag"]))
    }

    func testCLIEntryIsProcessMainNotSwiftUIInit() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent("Sources/PrimMac/App.swift"), encoding: .utf8)
        let main = try String(
            contentsOf: root.appendingPathComponent("Sources/PrimMac/PrimDesktopMain.swift"),
            encoding: .utf8
        )
        let cli = try String(
            contentsOf: root.appendingPathComponent("Sources/PrimMacCore/DesktopCLI.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(
            app.split("\n").contains(where: { $0 == "@main" || $0.hasPrefix("@main ") }),
            "PrimApp must not be @main — that starts NSApplication"
        )
        XCTAssertFalse(app.contains("DesktopCLI"), "App.swift must not peek CLI — that is an init() gate")
        XCTAssertTrue(main.contains("@main"))
        XCTAssertTrue(main.contains("enum PrimDesktopMain") || main.contains("struct PrimDesktopMain"))
        XCTAssertTrue(main.contains("ProcessEntry.shouldRunCLI"))
        XCTAssertTrue(main.contains("DesktopCLI.run"))
        XCTAssertTrue(main.contains("_exit"))
        XCTAssertTrue(main.contains("PrimApp.main()"))
        let exitRange = try XCTUnwrap(main.range(of: "_exit"))
        let glassRange = try XCTUnwrap(main.range(of: "PrimApp.main()"))
        XCTAssertTrue(exitRange.lowerBound < glassRange.lowerBound, "_exit must come before PrimApp.main()")
        for verb in ["connectors", "status", "receive", "open", "doctor", "asmp", "config"] {
            XCTAssertTrue(cli.contains("case \"\(verb)\":"), "DesktopCLI.invoke missing \(verb)")
        }
        XCTAssertTrue(cli.contains("public static let commands"))
    }

    func testBuildScriptDoesNotDeepStompIdentifiers() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let build = try String(contentsOf: root.appendingPathComponent("scripts/build.sh"), encoding: .utf8)
        let joined = build.replacingOccurrences(of: "\\\n", with: " ")
        for line in joined.split(separator: "\n").map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }
            guard trimmed.contains("codesign") else { continue }
            if trimmed.contains("--deep") {
                XCTAssertTrue(
                    trimmed.contains("--verify"),
                    "build.sh must not codesign --deep (resets nested Identifier): \(trimmed)"
                )
            }
        }
        XCTAssertTrue(build.contains("--identifier"))
        XCTAssertTrue(build.contains("sh.prims.desktop"))
        XCTAssertFalse(build.contains(".app.bak"))
        XCTAssertFalse(build.contains("/Applications/Prims Desktop.app.bak"))
        XCTAssertTrue(build.contains("mktemp"))
        XCTAssertTrue(build.contains("Contents/MacOS/Prim"))
    }

    func testTrampolineAndInstallCLIExecAppExecutable() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let trampoline = try String(
            contentsOf: root.appendingPathComponent("scripts/prims-desktop-trampoline.sh"),
            encoding: .utf8
        )
        let install = try String(
            contentsOf: root.appendingPathComponent("scripts/install-cli.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(trampoline.contains("exec \"$PRIM\" \"$@\""))
        XCTAssertTrue(trampoline.contains("/Applications/Prims Desktop.app/Contents/MacOS/Prim"))
        XCTAssertFalse(trampoline.contains("Helpers/prims-desktop"))
        XCTAssertFalse(install.contains("codesign"))
        XCTAssertTrue(install.contains("Contents/MacOS/Prim"))
        XCTAssertTrue(install.contains("Contents/Helpers/prims-desktop"))
        XCTAssertTrue(install.contains("must not exec Contents/Helpers/prims-desktop"))
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
}
