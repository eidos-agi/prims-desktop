import AppKit
import SwiftUI

@main
struct PrimApp: App {
    @NSApplicationDelegateAdaptor(DeskAppDelegate.self) private var delegate
    @StateObject private var desk = DeskModel()

    init() {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        WindowGroup {
            HostView()
                .environmentObject(desk)
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Prims Desktop Help") {
                    if let url = URL(string: "https://prims.sh/desktop/") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            CommandGroup(replacing: .sidebar) {
                Button(desk.railHidden ? "Show Sidebar" : "Hide Sidebar") {
                    desk.toggleRailHidden()
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
        }

        Settings {
            DeskSettingsView()
                .environmentObject(desk)
        }
    }
}

final class DeskAppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }

    func application(_ app: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool { false }

    func application(_ app: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.title = "Prims Desktop"
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
