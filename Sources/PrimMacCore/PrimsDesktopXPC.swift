import AppKit
import Foundation

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

/// Hosted by the LaunchServices-launched app (glass or `--xpc-serve`).
/// Rendezvous is a 0600 endpoint file — not a shell-exec of MacOS/Prim.
public final class PrimsDesktopXPCHost: NSObject, NSXPCListenerDelegate {
    public static let shared = PrimsDesktopXPCHost()

    private let listener = NSXPCListener.anonymous()
    private let service = PrimsDesktopXPCService()
    private var started = false

    override private init() {
        super.init()
    }

    public func start() {
        guard !started else { return }
        listener.delegate = self
        listener.resume()
        writeEndpoint(listener.endpoint)
        started = true
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
        newConnection.exportedInterface = NSXPCInterface(with: PrimsDesktopXPCProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }

    private func writeEndpoint(_ endpoint: NSXPCListenerEndpoint) {
        let url = ProductIdentity.xpcEndpointURL()
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: endpoint, requiringSecureCoding: true)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            fputs("prims-desktop: failed to publish XPC endpoint: \(error)\n", stderr)
        }
    }

    private static func ensureHealthInApp() {
        DispatchQueue.global(qos: .utility).async {
            if ASMP.probeHealth() { return }
            _ = ASMP.serveHealth()
        }
    }
}

/// PATH / helper thin client. Launches the app via LaunchServices if needed.
/// Does not open chat.db.
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
        guard let endpoint = readEndpoint() else { return nil }
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
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
        guard let proxy = connection.remoteObjectProxy as? PrimsDesktopXPCProtocol else {
            connection.invalidate()
            return nil
        }
        proxy.runCommand(args) { status, stdout, stderr in
            out = (status, stdout, stderr)
            sem.signal()
        }
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if sem.wait(timeout: .now() + 0.05) == .success { break }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        connection.invalidate()
        if failed, out == nil {
            try? FileManager.default.removeItem(at: ProductIdentity.xpcEndpointURL())
            return nil
        }
        return out
    }

    private static func readEndpoint() -> NSXPCListenerEndpoint? {
        let url = ProductIdentity.xpcEndpointURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let endpoint = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSXPCListenerEndpoint.self,
                from: data
              )
        else {
            return nil
        }
        return endpoint
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
