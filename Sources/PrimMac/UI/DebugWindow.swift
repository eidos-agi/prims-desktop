import AppKit
import PrimMacCore
import SwiftUI

/// Detached Debug window. Same process as Prims Desktop, not a sheet, not a helper.
final class DebugSession: NSObject, NSWindowDelegate {
    static let shared = DebugSession()
    static let identifier = "sh.prims.desktop.debug"

    private var controller: NSWindowController?
    private var lastGeometry = Date.distantPast

    func show() {
        if controller == nil {
            controller = NSWindowController(window: makeWindow())
        }
        DayLog.event("debug.window.open")
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }

    func windowDidMove(_ notification: Notification) {
        throttle("debug.window.moved")
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        logFrame("debug.window.resized")
    }

    func windowDidChangeScreen(_ notification: Notification) {
        let name = controller?.window?.screen?.localizedName ?? "unknown"
        DayLog.event("debug.window.screen", name)
    }

    func windowWillClose(_ notification: Notification) {
        DayLog.event("debug.window.close")
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: DebugLogView())
        let window = NSWindow(contentViewController: host)
        window.title = "Debug — Prims Desktop"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 640, height: 460))
        window.minSize = NSSize(width: 360, height: 240)
        window.identifier = NSUserInterfaceItemIdentifier(Self.identifier)
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1)
        window.hidesOnDeactivate = false
        window.level = .normal
        window.delegate = self
        return window
    }

    private func throttle(_ event: String) {
        let now = Date()
        guard now.timeIntervalSince(lastGeometry) >= 0.35 else { return }
        lastGeometry = now
        logFrame(event)
    }

    private func logFrame(_ event: String) {
        guard let frame = controller?.window?.frame else { return }
        let detail = String(
            format: "x=%.0f y=%.0f w=%.0f h=%.0f",
            frame.origin.x, frame.origin.y, frame.size.width, frame.size.height
        )
        DayLog.event(event, detail)
    }
}

/// Paper face that tails today's day file live.
struct DebugLogView: View {
    @StateObject private var tail = DebugTail()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.black.opacity(0.08))
            ScrollViewReader { proxy in
                ScrollView {
                    Text(tail.text.isEmpty ? "Waiting for events…" : tail.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Ink.youInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(14)
                        .id("end")
                }
                .onChange(of: tail.text) { _ in
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
        }
        .background(Ink.paper)
        .preferredColorScheme(.light)
        .onAppear { tail.start() }
        .onDisappear { tail.stop() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prims Desktop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.youInk)
                Text(tail.fileName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Ink.mute)
            }
            Spacer()
            Circle()
                .fill(Color(red: 0.32, green: 0.55, blue: 0.34))
                .frame(width: 8, height: 8)
            Text("Live")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.mute)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Ink.paper)
    }
}

final class DebugTail: ObservableObject {
    @Published var text = ""
    @Published var fileName = ""

    private var timer: Timer?
    private var url: URL?
    private var offset: UInt64 = 0

    func start() {
        poll(reset: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.poll(reset: false)
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll(reset: Bool) {
        let store = DayLog.Store(directory: DayLog.defaultDirectory)
        let next = store.url()
        if reset || next != url {
            url = next
            fileName = next.lastPathComponent
            offset = 0
            text = ""
        }
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: offset)
            let data = handle.readDataToEndOfFile()
            guard !data.isEmpty else { return }
            offset += UInt64(data.count)
            if let chunk = String(data: data, encoding: .utf8) {
                text += chunk
            }
        } catch {
            // tail must not disturb the desk
        }
    }
}
