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

    /// Bundle executable. PATH CLI must exec this (TCC client_type 0).
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
}
