import AppKit
import Darwin
import Foundation
import Security

/// XPC contract. The LS-launched app process exports this; PATH is the client.
/// ChatDB runs only in the app. The client never calls sqlite3_open.
@objc public protocol PrimsDesktopXPCProtocol {
    func runCommand(_ args: [String], reply: @escaping (Int32, Data, Data) -> Void)
}

/// App-side XPC object. Invokes DesktopCLI in this process (the FDA client).
final class PrimsDesktopXPCService: NSObject, PrimsDesktopXPCProtocol {
    func runCommand(_ args: [String], reply: @escaping (Int32, Data, Data) -> Void) {
        DispatchQueue.main.async {
            let result = DesktopCLI.invoke(args)
            reply(
                result.status,
                Data(result.stdout.utf8),
                Data(result.stderr.utf8)
            )
        }
    }
}

/// Peer must be Developer ID Team Y6CQ4SWPWM and Identifier sh.prims.desktop.
public enum XPCPeerTrust {
    public static func isTrusted(pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        var code: SecCode?
        let attrs = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
              let code,
              SecCodeCheckValidity(code, [], nil) == errSecSuccess
        else {
            return false
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any]
        else {
            return false
        }
        let ident = info[kSecCodeInfoIdentifier as String] as? String ?? ""
        let team = info[kSecCodeInfoTeamIdentifier as String] as? String ?? ""
        return ident == ProductIdentity.bundleIdentifier && team == ProductIdentity.teamID
    }

    public static func peerPID(of fd: Int32) -> pid_t? {
        var pid: pid_t = 0
        var len = socklen_t(MemoryLayout<pid_t>.size)
        let rc = getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &len)
        return rc == 0 && pid > 0 ? pid : nil
    }
}

/// Hosted by the LaunchServices-launched app (glass or `--xpc-serve`).
/// Named mach service + unix socket. Never archives NSXPCListenerEndpoint.
public final class PrimsDesktopXPCHost: NSObject, NSXPCListenerDelegate {
    public static let shared = PrimsDesktopXPCHost()

    private let machListener = NSXPCListener(machServiceName: ProductIdentity.xpcServiceName)
    private let service = PrimsDesktopXPCService()
    private var started = false
    private var listenFD: Int32 = -1

    override private init() {
        super.init()
    }

    public func start() {
        guard !started else { return }
        started = true
        try? FileManager.default.removeItem(at: ProductIdentity.staleXpcEndpointURL())
        machListener.delegate = self
        machListener.resume()
        startSocketListener()
        Self.ensureHealthInApp()
    }

    public static func runHeadless() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        shared.start()
        app.run()
    }

    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard XPCPeerTrust.isTrusted(pid: newConnection.processIdentifier) else {
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: PrimsDesktopXPCProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }

    private func startSocketListener() {
        let url = ProductIdentity.xpcSocketURL()
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        unlink(url.path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            fputs("prims-desktop: XPC socket() failed\n", stderr)
            return
        }
        var addr = sockaddr_un()
        guard Self.fillUnix(&addr, path: url.path) else {
            close(fd)
            fputs("prims-desktop: XPC socket path too long\n", stderr)
            return
        }
        let bindRC = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindRC == 0, listen(fd, 16) == 0 else {
            close(fd)
            fputs("prims-desktop: XPC bind/listen failed\n", stderr)
            return
        }
        chmod(url.path, 0o600)
        listenFD = fd
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptLoop()
        }
    }

    private func acceptLoop() {
        let fd = listenFD
        guard fd >= 0 else { return }
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                break
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.handleSocket(client)
            }
        }
    }

    private func handleSocket(_ fd: Int32) {
        defer { close(fd) }
        guard let pid = XPCPeerTrust.peerPID(of: fd), XPCPeerTrust.isTrusted(pid: pid) else {
            return
        }
        guard let payload = XPCFrame.read(fd),
              let cmd = try? JSONDecoder().decode(XPCCommand.self, from: payload)
        else {
            return
        }
        let result = DispatchQueue.main.sync {
            DesktopCLI.invoke(cmd.args)
        }
        let reply = XPCReply(status: result.status, stdout: result.stdout, stderr: result.stderr)
        guard let data = try? JSONEncoder().encode(reply) else { return }
        _ = XPCFrame.write(fd, data)
    }

    fileprivate static func fillUnix(_ addr: inout sockaddr_un, path: String) -> Bool {
        addr.sun_family = sa_family_t(AF_UNIX)
        return path.withCString { src in
            let n = strlen(src) + 1
            return withUnsafeMutableBytes(of: &addr.sun_path) { raw -> Bool in
                guard n <= raw.count, let dst = raw.baseAddress else { return false }
                memcpy(dst, src, n)
                return true
            }
        }
    }

    private static func ensureHealthInApp() {
        DispatchQueue.global(qos: .utility).async {
            if ASMP.probeHealth() { return }
            _ = ASMP.serveHealth()
        }
    }
}

private struct XPCCommand: Codable {
    var args: [String]
}

private struct XPCReply: Codable {
    var status: Int32
    var stdout: String
    var stderr: String
}

private enum XPCFrame {
    static func write(_ fd: Int32, _ data: Data) -> Bool {
        guard data.count < 8_000_000 else { return false }
        var n = UInt32(data.count).bigEndian
        let header = withUnsafeBytes(of: &n) { Data($0) }
        return writeAll(fd, header) && writeAll(fd, data)
    }

    static func read(_ fd: Int32) -> Data? {
        guard let header = readExact(fd, 4) else { return nil }
        let n = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard n > 0, n < 8_000_000 else { return nil }
        return readExact(fd, Int(n))
    }

    private static func writeAll(_ fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { raw in
            var sent = 0
            let total = raw.count
            guard let base = raw.baseAddress else { return false }
            while sent < total {
                let n = Darwin.write(fd, base.advanced(by: sent), total - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }

    private static func readExact(_ fd: Int32, _ count: Int) -> Data? {
        var data = Data(count: count)
        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            var got = 0
            guard let base = raw.baseAddress else { return false }
            while got < count {
                let n = Darwin.read(fd, base.advanced(by: got), count - got)
                if n <= 0 { return false }
                got += n
            }
            return true
        }
        return ok ? data : nil
    }
}

/// PATH / helper thin client. Launches the app via LaunchServices if needed.
/// Does not open chat.db. Does not archive NSXPCListenerEndpoint.
public enum PrimsDesktopXPCClient {
    public static func run(_ args: [String]) -> Int32 {
        if args.isEmpty || args.contains("--help") || args.contains("-h") || args.first == "help" {
            fputs(DesktopCLI.usage + "\n", stdout)
            return 0
        }
        if args.first == "open" {
            return openApp(headless: false)
        }
        if args.first == "asmp", args.dropFirst().first == "serve" {
            return ensureAppAndHealth()
        }
        return invokeViaXPC(args)
    }

    public static func invokeViaXPC(_ args: [String]) -> Int32 {
        if let result = tryConnect(args) {
            return emit(result)
        }
        let launched = openApp(headless: true)
        if launched != 0 {
            return launched
        }
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            if let result = tryConnect(args) {
                return emit(result)
            }
        }
        fputs("prims-desktop: app XPC not ready — open Prims Desktop.app via LaunchServices\n", stderr)
        return 2
    }

    private static func emit(_ result: (Int32, Data, Data)) -> Int32 {
        if !result.1.isEmpty {
            FileHandle.standardOutput.write(result.1)
        }
        if !result.2.isEmpty {
            FileHandle.standardError.write(result.2)
        }
        return result.0
    }

    private static func tryConnect(_ args: [String]) -> (Int32, Data, Data)? {
        if let result = tryConnectMach(args) { return result }
        return tryConnectSocket(args)
    }

    private static func tryConnectMach(_ args: [String]) -> (Int32, Data, Data)? {
        let connection = NSXPCConnection(machServiceName: ProductIdentity.xpcServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: PrimsDesktopXPCProtocol.self)
        let sem = DispatchSemaphore(value: 0)
        var out: (Int32, Data, Data)?
        var failed = false
        connection.invalidationHandler = {
            failed = true
            sem.signal()
        }
        connection.interruptionHandler = {
            failed = true
            sem.signal()
        }
        connection.resume()
        if connection.processIdentifier > 0, !XPCPeerTrust.isTrusted(pid: connection.processIdentifier) {
            connection.invalidate()
            return nil
        }
        guard let proxy = connection.remoteObjectProxy as? PrimsDesktopXPCProtocol else {
            connection.invalidate()
            return nil
        }
        proxy.runCommand(args) { status, stdout, stderr in
            out = (status, stdout, stderr)
            sem.signal()
        }
        let deadline = Date().addingTimeInterval(0.8)
        while Date() < deadline {
            if sem.wait(timeout: .now() + 0.05) == .success { break }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        let pid = connection.processIdentifier
        if pid > 0, out != nil, !XPCPeerTrust.isTrusted(pid: pid) {
            connection.invalidate()
            return nil
        }
        connection.invalidate()
        if failed, out == nil { return nil }
        return out
    }

    private static func tryConnectSocket(_ args: [String]) -> (Int32, Data, Data)? {
        let path = ProductIdentity.xpcSocketURL().path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var addr = sockaddr_un()
        guard PrimsDesktopXPCHost.fillUnix(&addr, path: path) else { return nil }
        let rc = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard rc == 0 else { return nil }
        guard let pid = XPCPeerTrust.peerPID(of: fd), XPCPeerTrust.isTrusted(pid: pid) else {
            return nil
        }
        guard let payload = try? JSONEncoder().encode(XPCCommand(args: args)),
              XPCFrame.write(fd, payload),
              let replyData = XPCFrame.read(fd),
              let reply = try? JSONDecoder().decode(XPCReply.self, from: replyData)
        else {
            return nil
        }
        return (reply.status, Data(reply.stdout.utf8), Data(reply.stderr.utf8))
    }

    public static func appIsRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == ProductIdentity.bundleIdentifier
        }
    }

    /// LaunchServices only. Never posix_spawn Contents/MacOS/Prim.
    @discardableResult
    public static func openApp(headless: Bool) -> Int32 {
        if appIsRunning() { return 0 }
        let app = ProductIdentity.appURL()
        guard FileManager.default.fileExists(atPath: app.path) else {
            fputs("prims-desktop: app not found at \(app.path)\n", stderr)
            return 1
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = !headless
        config.createsNewApplicationInstance = false
        if headless {
            config.arguments = [ProcessEntry.xpcServeFlag]
        }
        var status: Int32 = 0
        var finished = false
        NSWorkspace.shared.openApplication(at: app, configuration: config) { _, error in
            if error != nil { status = 1 }
            finished = true
        }
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            if finished || appIsRunning() { break }
        }
        return status
    }

    private static func ensureAppAndHealth() -> Int32 {
        if openApp(headless: true) != 0 { return 1 }
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if ASMP.probeHealth() { return 0 }
            Thread.sleep(forTimeInterval: 0.2)
        }
        fputs("prims-desktop: health listener did not come up\n", stderr)
        return 2
    }
}
