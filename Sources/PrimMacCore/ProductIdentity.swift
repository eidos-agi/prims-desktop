import Foundation

/// Locked Mac app identity. Do not invent names.
public enum ProductIdentity {
    public static let displayName = "Prims Desktop"
    public static let bundleIdentifier = "sh.prims.desktop"
    public static let executableName = "Prim"
    public static let packUTI = "com.eidosagi.prim"
    public static let teamID = "Y6CQ4SWPWM"
    public static let appPath = "/Applications/Prims Desktop.app"
    public static let helperName = "prims-desktop"
    public static let chatdbHelperName = "imessage-chatdb-receive"

    /// User-facing FDA copy. Never name ~/.local/bin.
    public static let fdaNote = "Prims Desktop needs Full Disk Access to read Messages on this Mac."

    public static func appURL() -> URL {
        URL(fileURLWithPath: appPath)
    }

    /// Bundle executable. Only the LaunchServices-launched instance is the FDA client.
    public static func executableURL() -> URL {
        appURL()
            .appendingPathComponent("Contents/MacOS")
            .appendingPathComponent(executableName)
    }

    public static func helpersDirectory() -> URL {
        appURL().appendingPathComponent("Contents/Helpers")
    }

    public static func cliHelperURL() -> URL {
        helpersDirectory().appendingPathComponent(helperName)
    }

    public static func chatdbHelperURL() -> URL {
        helpersDirectory().appendingPathComponent(chatdbHelperName)
    }

    public static func trampolineURL() -> URL {
        Paths.home().appendingPathComponent(".local/bin/prims-desktop")
    }

    public static func supportDirectory() -> URL {
        Paths.home()
            .appendingPathComponent("Library/Application Support/Prims Desktop")
    }

    /// Named mach service the LS-launched app publishes (1Password-style).
    /// Team-prefixed so the peer check matches Developer ID Y6CQ4SWPWM.
    public static let xpcServiceName = "Y6CQ4SWPWM.sh.prims.desktop.xpc"

    /// Unix-domain rendezvous for the named service. Not an archived endpoint.
    /// NSXPCListenerEndpoint cannot be NSKeyedArchiver-encoded (NSCocoaErrorDomain 4866).
    public static func xpcSocketURL() -> URL {
        supportDirectory().appendingPathComponent("cli.sock")
    }

    /// Leftover invalid archive from 7c0a11a. Never write this.
    public static func staleXpcEndpointURL() -> URL {
        supportDirectory().appendingPathComponent("cli.xpc.endpoint")
    }
}
