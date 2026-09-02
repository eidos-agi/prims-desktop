import Darwin
import Foundation

/// argv router and TCC process classification.
///
/// Empty argv (Finder / LaunchServices) is the human glass.
/// `--xpc-serve` is a headless app process (still LS-launched).
/// A CLI verb in a shell-exec'd Mach-O must talk XPC — it must not open chat.db.
public enum ProcessEntry {
    public static var commands: Set<String> { DesktopCLI.commands }
    public static var globalFlags: Set<String> { DesktopCLI.globalFlags }
    public static let xpcServeFlag = "--xpc-serve"

    /// Verbs that read chat.db. Must run in the LS-launched app via XPC.
    public static let appReaderCommands: Set<String> = ["doctor", "status", "receive"]

    /// `argumentsAfterArgv0` is `CommandLine.arguments` with argv0 dropped.
    public static func shouldRunCLI(_ argumentsAfterArgv0: [String]) -> Bool {
        guard let first = argumentsAfterArgv0.first else { return false }
        return DesktopCLI.commands.contains(first) || DesktopCLI.globalFlags.contains(first)
    }

    public static func isXPCServe(_ argumentsAfterArgv0: [String]) -> Bool {
        argumentsAfterArgv0.contains(xpcServeFlag)
    }

    public static func requiresAppReader(_ argumentsAfterArgv0: [String]) -> Bool {
        argumentsAfterArgv0.contains(where: { appReaderCommands.contains($0) })
    }

    /// The bundle executable, started by launchd / LaunchServices — TCC client_type 0.
    /// Shell-exec of MacOS/Prim (PATH trampoline, Terminal) is type 1 and stays locked.
    public static func isLaunchServicesAppProcess() -> Bool {
        let argv0 = CommandLine.arguments[0]
        guard argv0.contains("/Contents/MacOS/Prim") else { return false }
        let parent = parentProcessName()?.lowercased() ?? ""
        let base = URL(fileURLWithPath: parent).lastPathComponent.lowercased()
        return base == "launchd" || base.hasPrefix("launchd")
    }

    public static func parentProcessName() -> String? {
        let pid = getppid()
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let n = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return 0 }
            return proc_pidpath(pid, base, UInt32(ptr.count))
        }
        if n > 0 {
            return String(cString: buf)
        }
        return nil
    }
}

/// `_exit` skips stdio flush. Piped `prims-desktop doctor --json` printed zero bytes.
public enum ProcessExit {
    public static func flushAndExit(_ status: Int32) -> Never {
        fflush(stdout)
        fflush(stderr)
        _exit(status)
    }
}
