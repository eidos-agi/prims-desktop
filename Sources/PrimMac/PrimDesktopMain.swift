import Darwin
import PrimMacCore

/// Process entry for `/Applications/Prims Desktop.app/Contents/MacOS/Prim`.
///
/// CLI verbs must run and `_exit` here — before `PrimApp.main()`, before
/// `NSApplication`, before `DeskAppDelegate.applicationDidFinishLaunching`.
/// A check inside `PrimApp.init()` is too late; that is how `Prim doctor` hung.
@main
enum PrimDesktopMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if ProcessEntry.shouldRunCLI(args) {
            let status = DesktopCLI.run(args)
            _exit(status)
        }
        PrimApp.main()
    }
}
