import Darwin
import PrimMacCore

/// Process entry for `/Applications/Prims Desktop.app/Contents/MacOS/Prim`.
///
/// LaunchServices (Finder / `NSWorkspace.openApplication` / `--xpc-serve`)
/// hosts XPC and is the FDA client. A shell-exec CLI verb talks XPC and
/// `_exit`s after fflush — it must not call ChatDB in this process.
@main
enum PrimDesktopMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if ProcessEntry.isXPCServe(args) {
            PrimsDesktopXPCHost.runHeadless()
            return
        }
        if ProcessEntry.shouldRunCLI(args) {
            let status = PrimsDesktopXPCClient.run(args)
            ProcessExit.flushAndExit(status)
        }
        PrimsDesktopXPCHost.shared.start()
        PrimApp.main()
    }
}
