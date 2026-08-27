import Foundation
import PrimSimCore

/// Live ASMP announce for Prims Desktop connectors.
/// Health is loopback HTTP on 127.0.0.1:7749 — the probe eamd actually GETs.
public enum ASMP {
    public static let port: UInt16 = 7749
    public static let registryURL = URL(string: "http://127.0.0.1:7700")!
    public static let healthURL = URL(string: "http://127.0.0.1:7749/health")!

    public static func capability(for tool: PrimTool) -> String {
        "connector.\(tool.name)"
    }

    public static func liveCapabilities(connectors: [PrimTool]) -> [String] {
        var caps = ["prims-desktop.host", "prims-desktop.cli"]
        caps.append(contentsOf: connectors.map(capability(for:)).sorted())
        return caps
    }

    public static func writeManifest(connectors: [PrimTool], url: URL = Paths.asmpYAML()) throws {
        let caps = liveCapabilities(connectors: connectors)
        let capLines = caps.map { "    - \($0)" }.joined(separator: "\n")
        let antiPack = "prim." + "connector"
        let antiSurface = "prim." + "surface"
        let yaml = """
        asmp: "0.1"
        kind: service
        name: prims-desktop
        description: >
          Mac host for Prim packs and Prim Tool connectors. Connectors plus the
          prims-desktop CLI are the product. The window is secondary. Agents
          configure and operate through the CLI, not by driving the glass.
        version: 0.1.0
        created_by: agent://primdesktop
        owner: eidos-agi
        section: tools

        aliases:
          - prim-desktop
          - prim-mac
          - prim-mac-v1
          - prims desktop

        runtime:
          style: cli
          entrypoint: prims-desktop
          binary: ~/.local/bin/prims-desktop

        endpoints:
          - protocol: http
            host: 127.0.0.1
            port: \(port)
            path: /health
            visibility: loopback
            note: ASMP/eamd health probe
          - protocol: cli
            host: local
            visibility: local
            command: prims-desktop
            note: connectors / status / receive / doctor / open / asmp

        health:
          method: http
          target: http://127.0.0.1:\(port)/health
          interval: 30s
          timeout: 5s

        capabilities:
          provides:
        \(capLines)
          requires:
            - prim
            - asmp.registry
          optional:
            - messages.local
          anti_routes:
            - \(antiPack)
            - \(antiSurface)
            - desktop.prims.sh

        when_not_to_use:
          - Do not treat the Swift window as the prove surface. Use prims-desktop CLI.
          - Do not mint \(antiPack) or \(antiSurface) pack types.
          - Do not confuse this with prim-web or Volta.

        infra:
          repo: ~/repos-eidos-agi/prims-desktop
          github: https://github.com/eidos-agi/prims-desktop
          app: ~/Applications/Prims Desktop.app
          overlay: ~/.prim/registry.local.json
          health_port: \(port)
          verify:
            - prims-desktop doctor
            - prims-desktop connectors
            - prims-desktop asmp
            - ./scripts/prove.sh

        display:
          icon: square.stack
          label: Prims Desktop
          section: tools
        """
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (yaml + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    public static func hostManifest(connectors: [PrimTool]) -> [String: Any] {
        [
            "asmp": "0.1",
            "kind": "service",
            "name": "prims-desktop",
            "description": "Mac host for Prim packs and Prim Tool connectors. Connectors plus the prims-desktop CLI are the product.",
            "version": "0.1.0",
            "created_by": "agent://primdesktop",
            "owner": "eidos-agi",
            "section": "tools",
            "aliases": ["prim-desktop", "prim-mac", "prim-mac-v1", "prims desktop"],
            "runtime": [
                "style": "cli",
                "entrypoint": "prims-desktop",
                "binary": "~/.local/bin/prims-desktop",
            ],
            "endpoints": [
                [
                    "protocol": "http",
                    "host": "127.0.0.1",
                    "port": Int(port),
                    "path": "/health",
                    "visibility": "loopback",
                ],
                [
                    "protocol": "cli",
                    "host": "local",
                    "visibility": "local",
                    "command": "prims-desktop",
                ],
            ],
            "health": [
                "method": "http",
                "target": healthURL.absoluteString,
                "interval": "30s",
                "timeout": "5s",
            ],
            "capabilities": [
                "provides": liveCapabilities(connectors: connectors),
                "requires": ["prim", "asmp.registry"],
                "anti_routes": ["prim." + "connector", "prim." + "surface"],
            ],
            "infra": [
                "repo": "~/repos-eidos-agi/prims-desktop",
                "health_port": Int(port),
            ],
        ]
    }

    public static func connectorManifest(_ tool: PrimTool) -> [String: Any] {
        [
            "asmp": "0.1",
            "kind": "service",
            "name": tool.name,
            "description": "Prim Tool connector hosted by prims-desktop. Live from HostCatalog, not a frozen yaml list.",
            "version": "0.1.0",
            "created_by": "agent://primdesktop",
            "owner": "eidos-agi",
            "section": "tools",
            "parent": "prims-desktop",
            "endpoints": [[
                "protocol": "http",
                "host": "127.0.0.1",
                "port": Int(port),
                "path": "/health",
                "visibility": "loopback",
            ]],
            "health": [
                "method": "http",
                "target": healthURL.absoluteString,
            ],
            "capabilities": [
                "provides": [capability(for: tool)],
                "anti_routes": ["prim." + "connector", "prim." + "surface"],
            ],
            "infra": [
                "repo": "~/repos-eidos-agi/prims-desktop",
                "host_service": "prims-desktop",
            ],
        ]
    }

    public struct Report: Sendable {
        public var announced: [String]
        public var capabilities: [String]
        public var health: Bool
        public var healthURL: String
        public var yaml: String
        public var registry: String
    }

    /// Write live yaml, ensure loopback health, announce host + each connector.
    public static func announceLive(connectors: [PrimTool], spawnHealth: Bool = true) throws -> Report {
        try writeManifest(connectors: connectors)
        if spawnHealth {
            try ensureHealthServing()
        }
        var names = ["prims-desktop"]
        _ = try postAnnounce(hostManifest(connectors: connectors))
        for tool in connectors {
            _ = try postAnnounce(connectorManifest(tool))
            names.append(tool.name)
        }
        return Report(
            announced: names,
            capabilities: liveCapabilities(connectors: connectors),
            health: probeHealth(),
            healthURL: healthURL.absoluteString,
            yaml: Paths.asmpYAML().path,
            registry: registryURL.absoluteString
        )
    }

    public struct Doctor: Sendable {
        public var registered: Bool
        public var health: Bool
        public var capsMatch: Bool
        public var liveCaps: [String]
        public var registeredCaps: [String]
        public var missingCaps: [String]
        public var announcedConnectors: [String]
        public var note: String
    }

    public static func doctor(connectors: [PrimTool]) -> Doctor {
        let live = liveCapabilities(connectors: connectors)
        let host = getService("prims-desktop")
        let registered = host != nil
        let registeredCaps: [String]
        if let host,
           let caps = host["capabilities"] as? [String: Any],
           let provides = caps["provides"] as? [String] {
            registeredCaps = provides
        } else {
            registeredCaps = []
        }
        let missing = live.filter { !Set(registeredCaps).contains($0) }
        var announced: [String] = []
        for tool in connectors {
            if getService(tool.name) != nil { announced.append(tool.name) }
        }
        let health = probeHealth()
        var note = "registered=\(registered) health=\(health) caps_match=\(missing.isEmpty)"
        if !registered { note += " (asmp get prims-desktop missing)" }
        if !health { note += " (loopback \(healthURL.absoluteString) down — run prims-desktop asmp)" }
        if !missing.isEmpty { note += " (missing \(missing.joined(separator: ", ")))" }
        return Doctor(
            registered: registered,
            health: health,
            capsMatch: missing.isEmpty && registered,
            liveCaps: live,
            registeredCaps: registeredCaps,
            missingCaps: missing,
            announcedConnectors: announced,
            note: note
        )
    }

    public static func json(_ doctor: Doctor) -> [String: Any] {
        [
            "registered": doctor.registered,
            "health": doctor.health,
            "health_url": healthURL.absoluteString,
            "caps_match": doctor.capsMatch,
            "live_caps": doctor.liveCaps,
            "registered_caps": doctor.registeredCaps,
            "missing_caps": doctor.missingCaps,
            "announced_connectors": doctor.announcedConnectors,
            "note": doctor.note,
        ]
    }

    // MARK: - health listener

    public static func probeHealth() -> Bool {
        guard let (code, body) = try? httpGet(healthURL) else { return false }
        guard code == 200, let body,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return false }
        if let ok = obj["ok"] as? Bool { return ok }
        if let status = obj["status"] as? String {
            return ["ok", "healthy", "up", "ready"].contains(status.lowercased())
        }
        return false
    }

    public static func ensureHealthServing() throws {
        if probeHealth() { return }
        let bin = DesktopCLI.cliURL()
        guard FileManager.default.isExecutableFile(atPath: bin.path) else {
            throw LocalOverlay.OverlayError("prims-desktop CLI not installed at \(bin.path)")
        }
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = ["asmp", "serve"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        for _ in 0..<25 {
            Thread.sleep(forTimeInterval: 0.1)
            if probeHealth() { return }
        }
        throw LocalOverlay.OverlayError("health listener did not come up on \(healthURL.absoluteString)")
    }

    /// Block forever serving GET /health on 127.0.0.1:7749.
    public static func serveHealth() -> Int32 {
        if probeHealth() {
            fputs("prims-desktop: health already up on \(healthURL.absoluteString)\n", stderr)
            return 0
        }
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return 1 }
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindRC = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindRC != 0 {
            fputs("prims-desktop: bind 127.0.0.1:\(port) failed (errno \(errno))\n", stderr)
            close(fd)
            return 1
        }
        listen(fd, 16)
        let body = #"{"ok":true,"status":"ok","service":"prims-desktop"}"#
        let payload = Data(body.utf8)
        while true {
            let cfd = accept(fd, nil, nil)
            if cfd < 0 { continue }
            var buf = [UInt8](repeating: 0, count: 2048)
            _ = read(cfd, &buf, buf.count)
            var header = "HTTP/1.1 200 OK\r\n"
            header += "Content-Type: application/json\r\n"
            header += "Content-Length: \(payload.count)\r\n"
            header += "Connection: close\r\n\r\n"
            let data = Data(header.utf8) + payload
            data.withUnsafeBytes { raw in
                _ = write(cfd, raw.baseAddress, data.count)
            }
            close(cfd)
        }
    }

    // MARK: - registry HTTP

    public static func postAnnounce(_ manifest: [String: Any]) throws -> [String: Any] {
        let url = registryURL.appendingPathComponent("services/announce")
        let (code, data) = try httpJSON(method: "POST", url: url, body: manifest)
        guard let data,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw LocalOverlay.OverlayError("announce: empty response HTTP \(code)")
        }
        if code >= 400 {
            let err = obj["error"] as? String ?? "HTTP \(code)"
            throw LocalOverlay.OverlayError("announce failed: \(err)")
        }
        return obj
    }

    public static func getService(_ name: String) -> [String: Any]? {
        let url = registryURL.appendingPathComponent("services").appendingPathComponent(name)
        guard let (code, data) = try? httpGet(url), code == 200, let data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if obj["error"] != nil { return nil }
        return obj
    }

    private static func httpGet(_ url: URL) throws -> (Int, Data?) {
        try httpJSON(method: "GET", url: url, body: nil)
    }

    private static func httpJSON(method: String, url: URL, body: [String: Any]?) throws -> (Int, Data?) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
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
            throw error
        }
        return (box.code, box.data)
    }

    private final class HTTPBox: @unchecked Sendable {
        var data: Data?
        var error: Error?
        var code: Int = 0
    }
}
