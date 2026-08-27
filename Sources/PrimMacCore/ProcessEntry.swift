import Foundation

/// argv router for the bundle executable. Lives in PrimMacCore so HostTests
/// can lock it without constructing SwiftUI.
///
/// Empty argv (Finder / `open -a`) is the human glass. A CLI verb or global
/// CLI flag is `DesktopCLI` then `_exit` — never NSApplication.
public enum ProcessEntry {
    public static var commands: Set<String> { DesktopCLI.commands }
    public static var globalFlags: Set<String> { DesktopCLI.globalFlags }

    /// `argumentsAfterArgv0` is `CommandLine.arguments` with argv0 dropped.
    public static func shouldRunCLI(_ argumentsAfterArgv0: [String]) -> Bool {
        guard let first = argumentsAfterArgv0.first else { return false }
        return DesktopCLI.commands.contains(first) || DesktopCLI.globalFlags.contains(first)
    }
}
