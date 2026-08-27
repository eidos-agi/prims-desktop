import Foundation
import PrimSimCore

/// App CLI for Prim connectors. Human stdout by default; `--json` for machines.
public enum DesktopCLI {
    public struct Result: Sendable {
        public var status: Int32
        public var stdout: String
        public var stderr: String
    }

    public static let usage = """
    prims-desktop — configure and operate Prims Desktop connectors

      prims-desktop connectors
      prims-desktop status [<name>]
      prims-desktop receive imessage-chatdb-receive [--limit N]
      prims-desktop open
      prims-desktop doctor
      prims-desktop asmp
      prims-desktop config get [<name>]
      prims-desktop config set <name> <field> <value>
      prims-desktop cells
      prims-desktop cells add <id> --host H --port N --reach local|ssh [--ssh hop] [--notes text]
      prims-desktop health <tenant>
      prims-desktop ls <tenant>
      prims-desktop inspect <tenant> <id>
      prims-desktop logs <tenant> [<id>]
      prims-desktop send <tenant> <id> --no-wait <text>

    --json anywhere. Overlay is ~/.prim/registry.local.json (not a second store).
    Paseo tenants live in that overlay under paseo_tenants — one connector, more rows.
    ASMP health is http://127.0.0.1:7749/health (host only; not prims-connectors-paseo).
    """

    public static let fdaNote = ProductIdentity.fdaNote

    public static func run(_ args: [String]) -> Int32 {
        let result = invoke(args)
        if !result.stdout.isEmpty {
            fputs(result.stdout, stdout)
            if !result.stdout.hasSuffix("\n") { fputs("\n", stdout) }
        }
        if !result.stderr.isEmpty {
            fputs(result.stderr, stderr)
            if !result.stderr.hasSuffix("\n") { fputs("\n", stderr) }
        }
        return result.status
    }

    public static func invoke(_ args: [String]) -> Result {
        do {
            let parsed = try parse(args)
            if parsed.help || parsed.command.isEmpty || parsed.command == "help" {
                return Result(status: 0, stdout: usage + "\n", stderr: "")
            }
            switch parsed.command {
            case "connectors":
                return try cmdConnectors(json: parsed.json)
            case "status":
                if parsed.positionals.first == Paseo.connectorName {
                    let report = paseoStatus()
                    if parsed.json { return emitJSON(report.json, status: report.ok ? 0 : 2) }
                    return Result(status: report.ok ? 0 : 2, stdout: report.human + "\n", stderr: "")
                }
                return try cmdStatus(name: parsed.positionals.first, json: parsed.json)
            case "receive":
                return try cmdReceive(name: parsed.positionals.first, limit: parsed.limit, json: parsed.json)
            case "open":
                return try cmdOpen(json: parsed.json)
            case "doctor":
                return try cmdDoctor(json: parsed.json)
            case "asmp":
                return try cmdAsmp(parsed.positionals, json: parsed.json)
            case "config":
                return try cmdConfig(parsed.positionals, json: parsed.json)
            case "cells":
                return try cmdCells(parsed, json: parsed.json)
            case "health", "ls", "inspect", "logs", "send":
                return try cmdPaseo(parsed)
            case "run", "clone", "delete", "archive", "permit", "daemon", "recreate":
                return fail(1, "\(parsed.command) is out of v1 for \(Paseo.connectorName)", json: parsed.json)
            default:
                return fail(1, "unknown command \(parsed.command)", json: parsed.json)
            }
        } catch {
            return fail(1, error.localizedDescription, json: args.contains("--json"))
        }
    }

    // MARK: - commands

    private static func cmdConnectors(json: Bool) throws -> Result {
        let catalog = try HostCatalog.load()
        let rows = HostUI.connectors(catalog.registry.tools).map(row(for:))
        if json {
            return okJSON(["connectors": rows.map(\.json)])
        }
        if rows.isEmpty {
            return Result(status: 0, stdout: "no connectors\n", stderr: "")
        }
        let lines = rows.map(\.human)
        return Result(status: 0, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
    }

    private static func cmdStatus(name: String?, json: Bool) throws -> Result {
        let catalog = try HostCatalog.load()
        let tools: [PrimTool]
        if let name {
            guard let tool = catalog.registry.tool(named: name) else {
                return fail(1, "no connector named \(name)", json: json)
            }
            tools = [tool]
        } else {
            tools = HostUI.connectors(catalog.registry.tools)
        }
        let reports = tools.map { status(for: $0) }
        let allOk = reports.allSatisfy(\.ok)
        if json {
            let payload: [String: Any] = name == nil
                ? ["status": reports.map(\.json)]
                : reports[0].json
            return emitJSON(payload, status: allOk ? 0 : 2)
        }
        let text = reports.map(\.human).joined(separator: "\n") + "\n"
        return Result(status: allOk ? 0 : 2, stdout: text, stderr: "")
    }

    private static func cmdReceive(name: String?, limit: Int, json: Bool) throws -> Result {
        guard let name else {
            return fail(1, "receive needs a connector name", json: json)
        }
        let catalog = try HostCatalog.load()
        guard let tool = catalog.registry.tool(named: name) else {
            return fail(1, "no connector named \(name)", json: json)
        }
        guard tool.name == "imessage-chatdb-receive" else {
            return fail(1, "\(name) is not in-host; only imessage-chatdb-receive is operated here", json: json)
        }
        let received = ChatDB.receive(limit: limit)
        let note = received.ok ? received.note : fdaNote
        let messages: [[String: Any]] = received.messages.map { msg in
            var row: [String: Any] = [
                "ROWID": msg.rowid,
                "is_from_me": msg.fromMe,
                "text": clip(msg.text, 240),
            ]
            if let date = msg.date {
                row["date"] = ISO8601DateFormatter().string(from: date)
            }
            return row
        }
        var payload: [String: Any] = [
            "ok": received.ok,
            "name": name,
            "source": ChatDB.path,
            "limit": max(1, limit),
            "count": messages.count,
            "note": note,
            "messages": messages,
        ]
        if !received.ok {
            payload["error"] = fdaNote
        }
        if json {
            return emitJSON(payload, status: received.ok ? 0 : 2)
        }
        if !received.ok {
            return Result(status: 2, stdout: fdaNote + "\n", stderr: "")
        }
        if messages.isEmpty {
            return Result(status: 0, stdout: note + "\n", stderr: "")
        }
        var lines: [String] = [note]
        for msg in received.messages {
            let who = msg.fromMe ? "me" : "them"
            let text = clip(msg.text, 240)
            lines.append("  [\(msg.rowid)] \(who)  \(text)")
        }
        return Result(status: 0, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
    }

    private static func cmdOpen(json: Bool) throws -> Result {
        let app = appURL()
        guard FileManager.default.fileExists(atPath: app.path) else {
            return fail(1, "app not found at \(app.path)", json: json)
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Prims Desktop"]
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            return fail(1, "open -a \"Prims Desktop\" exited \(proc.terminationStatus)", json: json)
        }
        if json {
            return okJSON(["ok": true, "app": app.path])
        }
        return Result(status: 0, stdout: "opened \(app.path)\n", stderr: "")
    }

    private static func cmdDoctor(json: Bool) throws -> Result {
        let overlay = LocalOverlay.url()
        let overlayExists = FileManager.default.fileExists(atPath: overlay.path)
        let overlayTools = (try? LocalOverlay.load())?.tools.map(\.name) ?? []
        let app = appURL()
        let appExists = FileManager.default.fileExists(atPath: app.path)
        let appTeam = appExists ? teamIdentifier(for: app) : nil
        let trampoline = ProductIdentity.trampolineURL()
        let trampolineExists = FileManager.default.isExecutableFile(atPath: trampoline.path)
        let trampolineIsScript = trampolineExists && !isMachO(trampoline)
        let helper = helperURL()
        let helperExists = FileManager.default.isExecutableFile(atPath: helper.path)
        let helperTeam = helperExists ? teamIdentifier(for: helper) : nil
        let chatdbHelper = ProductIdentity.chatdbHelperURL()
        let chatdbHelperExists = FileManager.default.isExecutableFile(atPath: chatdbHelper.path)
        let readable = ChatDB.health()
        let connectors = (try? HostCatalog.load()).map { HostUI.connectors($0.registry.tools) } ?? []
        let asmp = ASMP.doctor(connectors: connectors)
        let payload: [String: Any] = [
            "overlay": overlay.path,
            "overlay_exists": overlayExists,
            "overlay_tools": overlayTools,
            "app": app.path,
            "app_exists": appExists,
            "bundle_identifier": ProductIdentity.bundleIdentifier,
            "codesign_team": appTeam ?? "",
            "cli": trampoline.path,
            "cli_exists": trampolineExists,
            "cli_is_trampoline": trampolineIsScript,
            "cli_team": "",
            "helper": helper.path,
            "helper_exists": helperExists,
            "helper_team": helperTeam ?? "",
            "chatdb_helper": chatdbHelper.path,
            "chatdb_helper_exists": chatdbHelperExists,
            "chat_db": ChatDB.path,
            "chat_db_readable": readable,
            "fda": readable,
            "fda_note": fdaNote,
            "asmp": ASMP.json(asmp),
        ]
        if json {
            return emitJSON(payload, status: 0)
        }
        let lines = [
            "overlay     \(overlay.path)\(overlayExists ? "" : "  (missing)")",
            "overlay tools  \(overlayTools.isEmpty ? "(none)" : overlayTools.joined(separator: ", "))",
            "app         \(app.path)\(appExists ? "" : "  (missing)")",
            "identifier  \(ProductIdentity.bundleIdentifier)",
            "codesign    \(appTeam ?? "(unsigned / unknown)")",
            "trampoline  \(trampoline.path)\(trampolineExists ? (trampolineIsScript ? "  (script)" : "  (NOT a trampoline)") : "  (not installed)")",
            "helper      \(helper.path)\(helperExists ? "" : "  (missing)")",
            "helper team \(helperTeam ?? "(unsigned / unknown)")",
            "chatdb helper  \(chatdbHelper.path)\(chatdbHelperExists ? "" : "  (missing)")",
            "chat.db     \(readable ? "readable" : "locked (FDA)")",
            "asmp        \(asmp.registered ? "registered" : "missing")  health=\(asmp.health ? "ok" : "down")  caps_match=\(asmp.capsMatch ? "yes" : "no")",
            "asmp health \(ASMP.healthURL.absoluteString)",
            "asmp connectors  \(asmp.announcedConnectors.isEmpty ? "(none announced)" : asmp.announcedConnectors.joined(separator: ", "))",
        ]
        return Result(status: 0, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
    }

    private static func cmdConfig(_ positionals: [String], json: Bool) throws -> Result {
        let action = positionals.first ?? "get"
        switch action {
        case "get":
            let local = try LocalOverlay.load()
            if let name = positionals.dropFirst().first {
                guard let tool = local.tool(named: name) else {
                    return fail(1, "\(name) is not in the overlay", json: json)
                }
                if json { return okJSON(row(for: tool).json) }
                return Result(status: 0, stdout: row(for: tool).human + "\n", stderr: "")
            }
            if json {
                return okJSON([
                    "path": LocalOverlay.url().path,
                    "tools": local.tools.map { row(for: $0).json },
                ])
            }
            var lines = ["overlay  \(LocalOverlay.url().path)"]
            if local.tools.isEmpty {
                lines.append("(empty)")
            } else {
                lines.append(contentsOf: local.tools.map { row(for: $0).human })
            }
            return Result(status: 0, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
        case "set":
            let rest = Array(positionals.dropFirst())
            guard rest.count >= 3 else {
                return fail(1, "config set needs <name> <field> <value>", json: json)
            }
            let catalog = try HostCatalog.load()
            let tool = try LocalOverlay.setField(tool: rest[0], field: rest[1], value: rest[2], catalog: catalog.registry)
            let preserved = (try LocalOverlay.load()).tools.map(\.name)
            if json {
                return okJSON([
                    "ok": true,
                    "tool": row(for: tool).json,
                    "overlay_tools": preserved,
                ])
            }
            return Result(
                status: 0,
                stdout: "set \(tool.name).\(rest[1])=\(rest[2])\noverlay tools  \(preserved.joined(separator: ", "))\n",
                stderr: ""
            )
        default:
            return fail(1, "config expects get or set", json: json)
        }
    }

    private static func cmdAsmp(_ positionals: [String], json: Bool) throws -> Result {
        if positionals.first == "serve" {
            // Forever. Does not return on success.
            return Result(status: ASMP.serveHealth(), stdout: "", stderr: "")
        }
        let catalog = try HostCatalog.load()
        let connectors = HostUI.connectors(catalog.registry.tools)
        let report = try ASMP.announceLive(connectors: connectors)
        if json {
            return okJSON([
                "ok": true,
                "announced": report.announced,
                "capabilities": report.capabilities,
                "health": report.health,
                "health_url": report.healthURL,
                "yaml": report.yaml,
                "registry": report.registry,
            ])
        }
        let lines = [
            "yaml       \(report.yaml)",
            "health     \(report.health ? "ok" : "down")  \(report.healthURL)",
            "announced  \(report.announced.joined(separator: ", "))",
            "caps       \(report.capabilities.joined(separator: ", "))",
        ]
        return Result(status: report.health ? 0 : 2, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
    }

    // MARK: - rows / status

    private struct ConnectorRow {
        var json: [String: Any]
        var human: String
    }

    private static func row(for tool: PrimTool) -> ConnectorRow {
        let inHost = HostUI.isInHost(tool)
        let json: [String: Any] = [
            "name": tool.name,
            "kind": tool.kind,
            "direction": tool.direction,
            "as": tool.as ?? "",
            "cites": tool.cites,
            "bin": tool.bin ?? "",
            "in_host": inHost,
        ]
        let human = [
            tool.name,
            tool.kind,
            tool.direction,
            "as=\(tool.as ?? "-")",
            "cites=\(tool.cites)",
            "bin=\(tool.bin ?? "-")",
            "in-host=\(inHost ? "yes" : "no")",
        ].joined(separator: "  ")
        return ConnectorRow(json: json, human: human)
    }

    private struct StatusReport {
        var ok: Bool
        var json: [String: Any]
        var human: String
    }

    private static func cmdCells(_ parsed: Parsed, json: Bool) throws -> Result {
        if parsed.positionals.first == "add" {
            return try cmdCellsAdd(parsed, json: json)
        }
        let tenants = try Paseo.ensureSeeded()
        if json {
            return okJSON([
                "ok": true,
                "connector": Paseo.connectorName,
                "path": LocalOverlay.url().path,
                "cells": tenants.map { $0.json() },
            ])
        }
        if tenants.isEmpty {
            return Result(status: 0, stdout: "\(Paseo.connectorName)  no cells\n", stderr: "")
        }
        var lines = ["\(Paseo.connectorName)  \(tenants.count) cells"]
        lines.append(contentsOf: tenants.map { "  \($0.human())" })
        return Result(status: 0, stdout: lines.joined(separator: "\n") + "\n", stderr: "")
    }

    private static func cmdCellsAdd(_ parsed: Parsed, json: Bool) throws -> Result {
        let rest = Array(parsed.positionals.dropFirst())
        guard let id = rest.first, !id.isEmpty else {
            return fail(1, "cells add needs <id> --host --port --reach", json: json)
        }
        guard let host = parsed.flags["host"], !host.isEmpty else {
            return fail(1, "cells add needs --host", json: json)
        }
        guard let portText = parsed.flags["port"], let port = Int(portText), port > 0 else {
            return fail(1, "cells add needs --port", json: json)
        }
        guard let reachText = parsed.flags["reach"], let reach = Paseo.Reach(rawValue: reachText) else {
            return fail(1, "cells add needs --reach local|ssh", json: json)
        }
        let tenant = Paseo.Tenant(
            id: id,
            host: host,
            port: port,
            reach: reach,
            ssh: parsed.flags["ssh"] ?? (reach == .ssh ? "hostkey" : ""),
            notes: parsed.flags["notes"] ?? ""
        )
        let tenants = try Paseo.addTenant(tenant)
        if json {
            return okJSON([
                "ok": true,
                "connector": Paseo.connectorName,
                "added": tenant.json(),
                "cells": tenants.map { $0.json() },
            ])
        }
        return Result(status: 0, stdout: "added \(tenant.human())\n", stderr: "")
    }

    private static func cmdPaseo(_ parsed: Parsed) throws -> Result {
        if parsed.follow {
            return fail(1, "logs is read-only; --follow is out of v1", json: parsed.json)
        }
        let verb = parsed.command
        guard let tenantID = parsed.positionals.first else {
            return fail(1, "\(verb) needs a tenant from the paseo registry", json: parsed.json)
        }
        if verb == "send" && !parsed.noWait {
            return fail(1, "send requires --no-wait", json: parsed.json)
        }
        let tenant: Paseo.Tenant
        do {
            tenant = try Paseo.tenant(named: tenantID)
        } catch {
            return fail(1, error.localizedDescription, json: parsed.json)
        }
        var extras: [String] = []
        if verb == "send" {
            extras.append("--no-wait")
            extras.append(contentsOf: Array(parsed.positionals.dropFirst()))
        } else {
            extras.append(contentsOf: Array(parsed.positionals.dropFirst()))
        }
        let result: Paseo.ExecResult
        do {
            result = try Paseo.operate(tenant: tenant, verb: verb, extras: extras)
        } catch {
            return fail(resultStatus(for: error), error.localizedDescription, json: parsed.json)
        }
        return emitPaseo(result, tenant: tenant, verb: verb, json: parsed.json)
    }

    private static func resultStatus(for error: Error) -> Int32 {
        let text = error.localizedDescription
        if text.contains("down") || text.contains("not on PATH") { return 2 }
        return 1
    }

    private static func emitPaseo(_ result: Paseo.ExecResult, tenant: Paseo.Tenant, verb: String, json: Bool) -> Result {
        var payload: [String: Any] = [
            "ok": result.status == 0,
            "connector": Paseo.connectorName,
            "tenant": tenant.id,
            "verb": verb,
            "host": result.host,
            "tunneled": result.tunneled,
            "argv": result.argv,
            "status": Int(result.status),
        ]
        if let data = result.stdout.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            payload["result"] = obj
        } else if !result.stdout.isEmpty {
            payload["result"] = result.stdout
        }
        if !result.stderr.isEmpty { payload["stderr"] = result.stderr }
        if result.status != 0 {
            payload["dark"] = true
            payload["error"] = result.stderr.isEmpty ? "paseo \(verb) exited \(result.status)" : result.stderr
        }
        if json {
            return emitJSON(payload, status: result.status == 0 ? 0 : 2)
        }
        if result.status != 0 {
            let err = result.stderr.isEmpty ? result.stdout : result.stderr
            return Result(status: 2, stdout: "", stderr: "prims-desktop: \(tenant.id) \(err.isEmpty ? "dark" : err)\n")
        }
        let body = result.stdout.isEmpty ? "\(verb) \(tenant.id) ok\n" : result.stdout
        return Result(status: 0, stdout: body.hasSuffix("\n") ? body : body + "\n", stderr: "")
    }

    private static func status(for tool: PrimTool) -> StatusReport {
        if Paseo.isPaseo(tool) {
            return paseoStatus()
        }
        if HostUI.isInHost(tool) {
            let readable = ChatDB.health()
            let note = readable ? "chat.db readable" : "chat.db locked (FDA)"
            let json: [String: Any] = [
                "name": tool.name,
                "ok": readable,
                "in_host": true,
                "chat_db": ChatDB.path,
                "chat_db_readable": readable,
                "fda": readable,
                "note": readable ? note : fdaNote,
            ]
            return StatusReport(
                ok: readable,
                json: json,
                human: "\(tool.name)  \(note)"
            )
        }
        let bin = resolveBin(tool)
        let exists = bin.map { FileManager.default.isExecutableFile(atPath: $0.path) } ?? false
        let json: [String: Any] = [
            "name": tool.name,
            "ok": exists || tool.bin == nil,
            "in_host": false,
            "bin": bin?.path ?? (tool.bin ?? ""),
            "bin_exists": exists,
        ]
        let note: String
        if let bin {
            note = exists ? "bin \(bin.path)" : "bin missing \(bin.path)"
        } else {
            note = "as=\(tool.as ?? tool.kind) (no bin)"
        }
        return StatusReport(
            ok: exists || tool.bin == nil,
            json: json,
            human: "\(tool.name)  \(note)"
        )
    }

    private static func resolveBin(_ tool: PrimTool) -> URL? {
        let names = [tool.bin, tool.name].compactMap { $0 }
        let roots = [
            ProductIdentity.helpersDirectory(),
            Paths.home().appendingPathComponent(".local/bin"),
        ]
        for root in roots {
            for name in names {
                let url = root.appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: url.path) { return url }
            }
        }
        if let name = names.first {
            return ProductIdentity.helpersDirectory().appendingPathComponent(name)
        }
        return nil
    }

    // MARK: - parse / emit

    private static func paseoStatus() -> StatusReport {
        let tenants = (try? Paseo.ensureSeeded()) ?? []
        let health = (try? Paseo.healthAll()) ?? (false, [])
        let reached = health.1.filter(\.ok).map(\.tenant.id)
        let dark = health.1.filter(\.dark).map(\.tenant.id)
        let bin = Paseo.whichPaseo()
        let ok = health.0
        var json: [String: Any] = [
            "name": Paseo.connectorName,
            "ok": ok,
            "in_host": false,
            "bin": bin?.path ?? "paseo",
            "bin_exists": bin != nil,
            "reached": ok,
            "tenants_ok": reached,
            "tenants_dark": dark,
            "tenants": health.1.map { row -> [String: Any] in
                var obj = row.tenant.json()
                obj["ok"] = row.ok
                obj["dark"] = row.dark
                obj["note"] = row.note
                return obj
            },
            "note": ok
                ? "reachable \(reached.joined(separator: ", "))"
                : (dark.isEmpty ? "no tenants" : "dark \(dark.joined(separator: ", "))"),
        ]
        if !ok { json["error"] = json["note"] as Any }
        return StatusReport(
            ok: ok,
            json: json,
            human: "\(Paseo.connectorName)  \(json["note"] as? String ?? "")"
        )
    }

    private struct Parsed {
        var json: Bool
        var help: Bool
        var limit: Int
        var noWait: Bool
        var follow: Bool
        var command: String
        var positionals: [String]
        var flags: [String: String]
    }

    private static func parse(_ args: [String]) throws -> Parsed {
        var json = false
        var help = false
        var limit = 8
        var noWait = false
        var follow = false
        var command = ""
        var positionals: [String] = []
        var flags: [String: String] = [:]
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg == "--json" {
                json = true
                i += 1
                continue
            }
            if arg == "--help" || arg == "-h" {
                help = true
                i += 1
                continue
            }
            if arg == "--no-wait" {
                noWait = true
                i += 1
                continue
            }
            if arg == "--follow" {
                follow = true
                i += 1
                continue
            }
            if arg == "--limit" || arg == "--host" || arg == "--port" || arg == "--reach" || arg == "--ssh" || arg == "--notes" {
                i += 1
                guard i < args.count else {
                    throw LocalOverlay.OverlayError("\(arg) needs a value")
                }
                let key = String(arg.dropFirst(2))
                flags[key] = args[i]
                if arg == "--limit" {
                    guard let n = Int(args[i]), n > 0 else {
                        throw LocalOverlay.OverlayError("--limit needs a positive integer")
                    }
                    limit = n
                }
                i += 1
                continue
            }
            if arg.hasPrefix("--") {
                throw LocalOverlay.OverlayError("unknown flag \(arg)")
            }
            if command.isEmpty {
                command = arg
            } else {
                positionals.append(arg)
            }
            i += 1
        }
        return Parsed(
            json: json,
            help: help,
            limit: limit,
            noWait: noWait,
            follow: follow,
            command: command,
            positionals: positionals,
            flags: flags
        )
    }

    private static func clip(_ text: String, _ n: Int) -> String {
        if text.count <= n { return text }
        return String(text.prefix(n)) + "…"
    }

    private static func fail(_ code: Int32, _ message: String, json: Bool) -> Result {
        if json {
            return emitJSON(["ok": false, "error": message], status: code)
        }
        return Result(status: code, stdout: "", stderr: "prims-desktop: \(message)\n")
    }

    private static func okJSON(_ obj: [String: Any]) -> Result {
        emitJSON(obj, status: 0)
    }

    private static func emitJSON(_ obj: [String: Any], status: Int32) -> Result {
        let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: opts),
              let text = String(data: data, encoding: .utf8)
        else {
            return Result(status: 1, stdout: "", stderr: "prims-desktop: JSON serialization failed\n")
        }
        return Result(status: status, stdout: text + "\n", stderr: "")
    }

    public static func appURL() -> URL {
        ProductIdentity.appURL()
    }

    public static func helperURL() -> URL {
        ProductIdentity.cliHelperURL()
    }

    public static func cliURL() -> URL {
        let helper = helperURL()
        if FileManager.default.isExecutableFile(atPath: helper.path) {
            return helper
        }
        let trampoline = ProductIdentity.trampolineURL()
        if FileManager.default.isExecutableFile(atPath: trampoline.path) {
            return trampoline
        }
        let argv0 = CommandLine.arguments[0]
        if argv0.hasPrefix("/") {
            return URL(fileURLWithPath: argv0)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(argv0)
    }

    public static func isMachO(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        let magic = fh.readData(ofLength: 4)
        guard magic.count == 4 else { return false }
        let word = magic.withUnsafeBytes { $0.load(as: UInt32.self) }
        switch word {
        case 0xfeedface, 0xcefaedfe, 0xfeedfacf, 0xcffaedfe, 0xcafebabe, 0xbebafeca:
            return true
        default:
            return false
        }
    }

    public static func teamIdentifier(for url: URL) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        proc.arguments = ["-dv", "--verbose=4", url.path]
        let err = Pipe()
        proc.standardError = err
        proc.standardOutput = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        let text = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in text.split(separator: "\n") {
            if line.hasPrefix("TeamIdentifier=") {
                let value = String(line.dropFirst("TeamIdentifier=".count))
                return value == "not set" ? nil : value
            }
        }
        return nil
    }
}
