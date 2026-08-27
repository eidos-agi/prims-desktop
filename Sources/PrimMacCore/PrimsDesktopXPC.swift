import AppKit
import Foundation
import Security
import ServiceManagement

/// Broker contract on the named mach service. Endpoint is passed over XPC
/// (NSXPCCoder). Never written to disk.
@objc public protocol PrimsDesktopXPCBrokerProtocol {
    func registerAppEndpoint(_ endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void)
    func runCommand(_ args: [String], reply: @escaping (Int32, Data, Data) -> Void)
}

/// App-side contract. ChatDB / DesktopCLI run only in the LS-launched app.
@objc public protocol PrimsDesktopXPCProtocol {
    func runCommand(_ args: [String], reply: @escaping (Int32, Data, Data) -> Void)
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
}

/// Registers the bundled LaunchAgent so launchd owns the named mach service.
public enum PrimsDesktopXPCAgent {
    public static func ensureRegistered() {
        let service = SMAppService.agent(plistName: ProductIdentity.xpcAgentPlistName)
        if service.status == .enabled { return }
        try? service.register()
    }
}

/// launchd starts this (`--xpc-broker`). No ChatDB. Forwards to the app endpoint.
public final class PrimsDesktopXPCBroker: NSObject, NSXPCListenerDelegate {
    public static let shared = PrimsDesktopXPCBroker()

    private let listener = NSXPCListener(machServiceName: ProductIdentity.xpcServiceName)
    private let lock = NSLock()
    private var appEndpoint: NSXPCListenerEndpoint?

    override private init() {
        super.init()
    }

    public static func run() -> Never {
        shared.start()
        RunLoop.main.run()
        fatalError("broker runloop returned")
    }

    public func start() {
        listener.delegate = self
        listener.resume()
    }

    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard XPCPeerTrust.isTrusted(pid: newConnection.processIdentifier) else {
            return false
        }
        let service = BrokerService(owner: self, connection: newConnection)
        newConnection.exportedInterface = NSXPCInterface(with: PrimsDesktopXPCBrokerProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }

    fileprivate func setAppEndpoint(_ endpoint: NSXPCListenerEndpoint?) {
        lock.lock()
        appEndpoint = endpoint
        lock.unlock()
    }

    fileprivate func currentAppEndpoint() -> NSXPCListenerEndpoint? {
        lock.lock()
        defer { lock.unlock() }
        return appEndpoint
    }
}

private final class BrokerService: NSObject, PrimsDesktopXPCBrokerProtocol {
    private weak var owner: PrimsDesktopXPCBroker?
    private weak var connection: NSXPCConnection?

    init(owner: PrimsDesktopXPCBroker, connection: NSXPCConnection) {
        self.owner = owner
        self.connection = connection
    }

    func registerAppEndpoint(_ endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void) {
        guard let pid = connection?.processIdentifier, XPCPeerTrust.isTrusted(pid: pid) else {
            reply(false)
            return
        }
        owner?.setAppEndpoint(endpoint)
        reply(true)
    }

    func runCommand(_ args: [String], reply: @escaping (Int32, Data, Data) -> Void) {
        guard let pid = connection?.processIdentifier, XPCPeerTrust.isTrusted(pid: pid) else {
            reply(2, Data(), Data("prims-desktop: untrusted XPC peer\n".utf8))
            return
        }
        guard let endpoint = owner?.currentAppEndpoint() else {
            reply(2, Data(), Data("prims-desktop: app XPC not ready — open Prims Desktop.app via LaunchServices\n".utf8))
            return
        }
        let app = NSXPCConnection(listenerEndpoint: endpoint)
        app.remoteObjectInterface = NSXPCInterface(with: PrimsDesktopXPCProtocol.self)
        let sem = DispatchSemaphore(value: 0)
        var out: (Int32, Data, Data)?
        app.invalidationHandler = { sem.signal() }
        app.interruptionHandler = { sem.signal() }
        app.resume()
        guard let proxy = app.remoteObjectProxy as? PrimsDesktopXPCProtocol else {
            app.invalidate()
            reply(2, Data(), Data("prims-desktop: app XPC proxy missing\n".utf8))
            return
        }
        proxy.runCommand(args) { status, stdout, stderr in
            out = (status, stdout, stderr)
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 20)
        app.invalidate()
        if let out {
            reply(out.0, out.1, out.2)
        } else {
            reply(2, Data(), Data("prims-desktop: app XPC timed out\n".utf8))
        }
    }
}

/// LS-launched app. Anonymous listener; endpoint registered over the named service.
public final class PrimsDesktopXPCHost: NSObject, NSXPCListenerDelegate {
    public static let shared = PrimsDesktopXPCHost()

    private let anonymous = NSXPCListener.anonymous()
    private let service = AppXPCService()
    private var started = false
    private var brokerConnection: NSXPCConnection?

    override private init() {
        super.init()
    }

    public func start() {
        guard !started else { return }
        started = true
        try? FileManager.default.removeItem(at: ProductIdentity.staleXpcEndpointURL())
        PrimsDesktopXPCAgent.ensureRegistered()
        anonymous.delegate = self
        anonymous.resume()
        registerWithBroker()
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

    private func registerWithBroker() {
        let connection = NSXPCConnection(machServiceName: ProductIdentity.xpcServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: PrimsDesktopXPCBrokerProtocol.self)
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.registerWithBroker()
            }
        }
        connection.resume()
        brokerConnection = connection
        guard let proxy = connection.remoteObjectProxy as? PrimsDesktopXPCBrokerProtocol else {
            return
        }
        proxy.registerAppEndpoint(anonymous.endpoint) { _ in }
    }

    private static func ensureHealthInApp() {
        DispatchQueue.global(qos: .utility).async {
            if ASMP.probeHealth() { return }
            _ = ASMP.serveHealth()
        }
    }
}

private final class AppXPCService: NSObject, PrimsDesktopXPCProtocol {
    func runCommand(_ args: [String], reply: @escaping (Int32, Data, Data) -> Void) {
        DispatchQueue.main.async {
            let result = DesktopCLI.invoke(args)
            reply(result.status, Data(result.stdout.utf8), Data(result.stderr.utf8))
        }
    }
}

/// PATH / helper thin client. NSXPCConnection to the named mach service.
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
        let connection = NSXPCConnection(machServiceName: ProductIdentity.xpcServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: PrimsDesktopXPCBrokerProtocol.self)
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
        guard let proxy = connection.remoteObjectProxy as? PrimsDesktopXPCBrokerProtocol else {
            connection.invalidate()
            return nil
        }
        proxy.runCommand(args) { status, stdout, stderr in
            out = (status, stdout, stderr)
            sem.signal()
        }
        let deadline = Date().addingTimeInterval(8)
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
