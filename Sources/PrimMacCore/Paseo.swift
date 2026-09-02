import Foundation
import PrimSimCore

/// One Desktop connector. Tenants are catalog rows in the same overlay
/// the rest of the app already writes (`~/.prim/registry.local.json`).
public enum Paseo {
    public static let connectorName = "prims-connectors-paseo"
    public static let overlayKey = "paseo_tenants"
    public static let proveAgent = "102adae1-a260-47dc-b8b1-087cfed7aff3"
    public static let proveTenant = "paseo-gmw"

    /// Desktop v1. `health` is HTTP `/api/health` on the cell, not a paseo verb.
    public static let v1Verbs: Set<String> = ["cells", "health", "ls", "inspect", "logs", "send"]
    public static let v1PaseoVerbs: Set<String> = ["ls", "inspect", "logs", "send"]
    public static let outOfV1: Set<String> = [
        "run", "clone", "delete", "archive", "permit", "daemon", "recreate",
    ]

    public static let connectorTool = PrimTool(
        name: connectorName,
        kind: "connector",
        direction: "operate",
        cites: "*",
        as: "paseo",
        bin: "paseo",
        repo: "local"
    )

    /// Daniel 2026-08-27: the app owns this registry. Seed the seven
    /// cells that already exist. Do not recreate them.
    public static let seedTenants: [Tenant] = [
        Tenant(id: "laptop", host: "127.0.0.1", port: 6767, reach: .local, ssh: "", notes: "local Mac daemon"),
        Tenant(id: "paseo-eidos", host: "127.0.0.1", port: 16767, reach: .ssh, ssh: "hostkey", notes: "hostkey loopback"),
        Tenant(id: "paseo-gmw", host: "127.0.0.1", port: 16768, reach: .ssh, ssh: "hostkey", notes: "hostkey loopback"),
        Tenant(id: "paseo-arp", host: "127.0.0.1", port: 16769, reach: .ssh, ssh: "hostkey", notes: "hostkey loopback"),
        Tenant(id: "paseo-aic", host: "127.0.0.1", port: 16770, reach: .ssh, ssh: "hostkey", notes: "hostkey loopback"),
        Tenant(id: "paseo-reeves", host: "127.0.0.1", port: 16771, reach: .ssh, ssh: "hostkey", notes: "hostkey loopback"),
        Tenant(id: "paseo-prims", host: "127.0.0.1", port: 16777, reach: .ssh, ssh: "hostkey", notes: "hostkey loopback"),
    ]

    public enum Reach: String, Sendable {
        case local
        case ssh
    }

    public struct Tenant: Sendable, Equatable {
        public var id: String
        public var host: String
        public var port: Int
        public var reach: Reach
        public var ssh: String
        public var notes: String

        public var name: String { id }

        /// Cerebroski prove: remote :16768 forwarded to local :26768.
        public var localForwardPort: Int {
            reach == .ssh ? port + 10_000 : port
        }

        public var remoteTarget: String { "\(host):\(port)" }

        public var operateHost: String {
            reach == .ssh ? "127.0.0.1:\(localForwardPort)" : remoteTarget
        }

        public var apiHealthURL: URL {
            URL(string: "http://\(operateHost)/api/health")!
        }

        public func json() -> [String: Any] {
            [
                "id": id,
                "name": name,
                "host": host,
                "port": port,
                "reach": reach.rawValue,
                "ssh": ssh,
                "notes": notes,
                "forward": reach == .ssh ? "127.0.0.1:\(localForwardPort)" : "",
            ]
        }

        public func human() -> String {
            let hop = reach == .ssh ? "  ssh \(ssh.isEmpty ? "hostkey" : ssh)" : "  local"
            let extra = notes.isEmpty ? "" : "  \(notes)"
            return "\(id)  \(remoteTarget)\(hop)\(extra)"
        }
    }

    public struct ExecResult: Sendable {
        public var status: Int32
        public var stdout: String
        public var stderr: String
        public var argv: [String]
        public var host: String
        public var tunneled: Bool
    }

    public struct TenantHealth: Sendable {
        public var tenant: Tenant
        public var ok: Bool
        public var dark: Bool
        public var note: String
        public var url: String
        public var http: Int
        public var argv: [String]
    }

    /// Test hook. When set, `paseo` is not spawned.
    public static var execHook: (([String]) throws -> ExecResult)?
    /// Test hook. When set, SSH is not spawned.
    public static var tunnelHook: ((Tenant) throws -> Void)?
    /// Test hook. When set, `/api/health` is not fetched.
    public static var healthHook: ((Tenant, URL) throws -> (Int, String))?

    public static func resetTestHooks() {
        execHook = nil
        tunnelHook = nil
        healthHook = nil
    }

    public static func isPaseo(_ tool: PrimTool) -> Bool {
        tool.name == connectorName || tool.as == "paseo"
    }

    // MARK: - overlay (same file as other Desktop connector config)

    @discardableResult
    public static func ensureSeeded() throws -> [Tenant] {
        var local = try LocalOverlay.load()
        var dirty = false
        if local.tool(named: connectorName) == nil {
            local.tools.append(connectorTool)
            dirty = true
        }
        var tenants = try loadTenants()
        var byID = Dictionary(uniqueKeysWithValues: tenants.map { ($0.id, $0) })
        for seed in seedTenants where byID[seed.id] == nil {
            tenants.append(seed)
            byID[seed.id] = seed
            dirty = true
        }
        if dirty {
            try LocalOverlay.save(local)
            try saveTenants(tenants)
        }
        return try loadTenants()
    }

    public static func loadTenants() throws -> [Tenant] {
        let raw = try LocalOverlay.loadRaw()
        guard let rows = raw[overlayKey] as? [[String: Any]] else { return [] }
        return rows.compactMap(tenant(from:)).sorted { $0.id < $1.id }
    }

    public static func saveTenants(_ tenants: [Tenant]) throws {
        try LocalOverlay.mergeRaw([
            overlayKey: tenants.sorted { $0.id < $1.id }.map { $0.json() },
        ])
    }

    public static func tenant(named id: String) throws -> Tenant {
        let tenants = try ensureSeeded()
        if let hit = tenants.first(where: { $0.id == id }) { return hit }
        throw LocalOverlay.OverlayError("no paseo tenant named \(id)")
    }

    public static func addTenant(_ tenant: Tenant) throws -> [Tenant] {
        _ = try ensureSeeded()
        var tenants = try loadTenants()
        if tenants.contains(where: { $0.id == tenant.id }) {
            throw LocalOverlay.OverlayError("tenant \(tenant.id) already exists")
        }
        tenants.append(tenant)
        try saveTenants(tenants)
        return try loadTenants()
    }

    private static func tenant(from row: [String: Any]) -> Tenant? {
        let id = (row["id"] as? String) ?? (row["name"] as? String) ?? ""
        guard !id.isEmpty else { return nil }
        let host = (row["host"] as? String) ?? "127.0.0.1"
        let port: Int
        if let n = row["port"] as? Int {
            port = n
        } else if let n = row["port"] as? NSNumber {
            port = n.intValue
        } else if let s = row["port"] as? String, let n = Int(s) {
            port = n
        } else {
            return nil
        }
        let reachRaw = (row["reach"] as? String) ?? "local"
        let reach = Reach(rawValue: reachRaw) ?? .local
        let ssh = (row["ssh"] as? String) ?? ""
        let notes = (row["notes"] as? String) ?? ""
        return Tenant(id: id, host: host, port: port, reach: reach, ssh: ssh, notes: notes)
    }

    // MARK: - operate

    public static func argv(verb: String, host: String, extras: [String]) -> [String] {
        var args = ["paseo", verb, "--json", "--host", host]
        args.append(contentsOf: extras)
        return args
    }

    public static func operate(tenant: Tenant, verb: String, extras: [String] = []) throws -> ExecResult {
        if verb == "send" && !extras.contains("--no-wait") {
            throw LocalOverlay.OverlayError("send requires --no-wait")
        }
        if verb == "logs" && extras.contains("--follow") {
            throw LocalOverlay.OverlayError("logs is read-only; --follow is out of v1")
        }
        if verb == "health" {
            throw LocalOverlay.OverlayError("paseo has no health verb; probe /api/health")
        }
        if outOfV1.contains(verb) {
            throw LocalOverlay.OverlayError("\(verb) is out of v1 for \(connectorName)")
        }
        if !v1PaseoVerbs.contains(verb) {
            throw LocalOverlay.OverlayError("unknown paseo verb \(verb)")
        }
        return try withReach(tenant) { host in
            let args = argv(verb: verb, host: host, extras: extras)
            if let hook = execHook {
                return try hook(args)
            }
            return try runPaseo(args, host: host, tunneled: tenant.reach == .ssh)
        }
    }

    /// Cerebroski prove: cell `/api/health` 200. Native paseo 0.6.1 has no health verb.
    public static func health(tenant: Tenant) -> TenantHealth {
        let url = tenant.apiHealthURL
        do {
            return try withReach(tenant) { host in
                let target = URL(string: "http://\(host)/api/health") ?? url
                let (code, body) = try getAPIHealth(tenant: tenant, url: target)
                let ok = isHealthy(code: code, body: body)
                return TenantHealth(
                    tenant: tenant,
                    ok: ok,
                    dark: !ok,
                    note: ok ? "reachable \(target.absoluteString)" : "dark \(target.absoluteString) HTTP \(code)",
                    url: target.absoluteString,
                    http: code,
                    argv: ["GET", target.absoluteString]
                )
            }
        } catch {
            return TenantHealth(
                tenant: tenant,
                ok: false,
                dark: true,
                note: error.localizedDescription,
                url: url.absoluteString,
                http: 0,
                argv: ["GET", url.absoluteString]
            )
        }
    }

    public static func healthAll() throws -> (ok: Bool, rows: [TenantHealth]) {
        let tenants = try ensureSeeded()
        if tenants.isEmpty { return (false, []) }
        if execHook != nil || tunnelHook != nil {
            let rows = tenants.map { health(tenant: $0) }
            return (rows.contains(where: \.ok), rows)
        }
        let lock = NSLock()
        var scored: [TenantHealth] = []
        let group = DispatchGroup()
        for tenant in tenants {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let row = health(tenant: tenant)
                lock.lock()
                scored.append(row)
                lock.unlock()
                group.leave()
            }
        }
        _ = group.wait(timeout: .now() + 8)
        let known = Set(scored.map { $0.tenant.id })
        for tenant in tenants where !known.contains(tenant.id) {
            scored.append(TenantHealth(
                tenant: tenant,
                ok: false,
                dark: true,
                note: "probe timeout",
                url: tenant.apiHealthURL.absoluteString,
                http: 0,
                argv: ["GET", tenant.apiHealthURL.absoluteString]
            ))
        }
        let rows = scored.sorted { $0.tenant.id < $1.tenant.id }
        return (rows.contains(where: \.ok), rows)
    }

    // MARK: - reach (connector-owned forward; no ~/.ssh/config writes)

    private static func getAPIHealth(tenant: Tenant, url: URL) throws -> (Int, String) {
        if let hook = healthHook {
            return try hook(tenant, url)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let box = HTTPBox()
        let sem = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            box.data = data
            box.error = error
            box.code = (response as? HTTPURLResponse)?.statusCode ?? 0
            sem.signal()
        }
        task.resume()
        if sem.wait(timeout: .now() + 6) == .timedOut {
            throw LocalOverlay.OverlayError("timeout \(url.absoluteString)")
        }
        if let error = box.error {
            throw LocalOverlay.OverlayError("\(url.absoluteString) \(error.localizedDescription)")
        }
        let text = box.data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return (box.code, text)
    }

    private static func isHealthy(code: Int, body: String) -> Bool {
        guard code == 200 else { return false }
        if body.isEmpty { return true }
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return true }
        if let ok = obj["ok"] as? Bool { return ok }
        if let status = obj["status"] as? String {
            return ["ok", "healthy", "up", "ready"].contains(status.lowercased())
        }
        return true
    }

    private final class HTTPBox: @unchecked Sendable {
        var data: Data?
        var error: Error?
        var code: Int = 0
    }

    private static func withReach<T>(_ tenant: Tenant, run: (String) throws -> T) throws -> T {
        if tenant.reach == .local {
            return try run(tenant.operateHost)
        }
        if let hook = tunnelHook {
            try hook(tenant)
            return try run(tenant.operateHost)
        }
        let hop = tenant.ssh.isEmpty ? "hostkey" : tenant.ssh
        let tunnel = try SSHForward.open(
            hop: hop,
            localPort: tenant.localForwardPort,
            remoteHost: tenant.host,
            remotePort: tenant.port
        )
        defer { tunnel.close() }
        return try run(tenant.operateHost)
    }

    private static func runPaseo(_ args: [String], host: String, tunneled: Bool) throws -> ExecResult {
        guard let bin = whichPaseo() else {
            throw LocalOverlay.OverlayError("paseo not on PATH")
        }
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = Array(args.dropFirst())
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
        } catch {
            throw LocalOverlay.OverlayError("paseo failed to start: \(error.localizedDescription)")
        }
        proc.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ExecResult(
            status: proc.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            argv: args,
            host: host,
            tunneled: tunneled
        )
    }

    public static func whichPaseo() -> URL? {
        let names = ["paseo"]
        var roots = [
            URL(fileURLWithPath: "/opt/homebrew/bin"),
            URL(fileURLWithPath: "/usr/local/bin"),
            Paths.home().appendingPathComponent(".local/bin"),
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            roots.append(contentsOf: path.split(separator: ":").map { URL(fileURLWithPath: String($0)) })
        }
        for root in roots {
            for name in names {
                let url = root.appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: url.path) { return url }
            }
        }
        return nil
    }

    /// Connector-owned LocalForward. Never writes ~/.ssh/config.
    public final class SSHForward: @unchecked Sendable {
        private let proc: Process
        public let localPort: Int
        public let hop: String

        private init(proc: Process, localPort: Int, hop: String) {
            self.proc = proc
            self.localPort = localPort
            self.hop = hop
        }

        public static func open(hop: String, localPort: Int, remoteHost: String, remotePort: Int) throws -> SSHForward {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            proc.arguments = [
                "-N",
                "-L", "\(localPort):\(remoteHost):\(remotePort)",
                "-o", "ExitOnForwardFailure=yes",
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                hop,
            ]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
            } catch {
                throw LocalOverlay.OverlayError("ssh hop \(hop) down")
            }
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if !proc.isRunning {
                    throw LocalOverlay.OverlayError("ssh hop \(hop) down")
                }
                if portOpen(localPort) { break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            if !portOpen(localPort) {
                if proc.isRunning { proc.terminate() }
                throw LocalOverlay.OverlayError("ssh hop \(hop) down")
            }
            return SSHForward(proc: proc, localPort: localPort, hop: hop)
        }

        public func close() {
            if proc.isRunning {
                proc.terminate()
                proc.waitUntilExit()
            }
        }

        deinit { close() }
    }

    private static func portOpen(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let rc = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return rc == 0
    }
}
