import AppKit
import Combine
import PrimMacCore
import PrimSimCore
import SwiftUI

/// Locked three doors. Messages rows live on Connectors (iMessage). Chat is not a Messages costume.
enum DeskDoor: String, CaseIterable, Identifiable {
    case viewer
    case connectors
    case chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewer: return "Viewer"
        case .connectors: return "Connectors"
        case .chat: return "Chat"
        }
    }

    var icon: String {
        switch self {
        case .viewer: return "doc.text"
        case .connectors: return "link"
        case .chat: return "bubble.left.and.bubble.right"
        }
    }
}

/// Shared desk state. Rail selection survives collapse; Settings does not replace the stage.
/// TASK-0014: this process (LS-launched Prims Desktop.app) opens chat.db. Do not wait on PATH/XPC.
final class DeskModel: ObservableObject {
    private static let selectedKey = "desk.selected"
    private static let railHiddenKey = "desk.railHidden"
    private static let railIconsKey = "desk.railIcons"

    @Published var catalog: HostCatalog
    @Published var door: DeskDoor = .connectors
    @Published var selected: String?
    @Published var chat: ChatDB.Receive?
    @Published var askFDA = false
    @Published var railHidden: Bool {
        didSet { UserDefaults.standard.set(railHidden, forKey: Self.railHiddenKey) }
    }
    @Published var railIcons: Bool {
        didSet { UserDefaults.standard.set(railIcons, forKey: Self.railIconsKey) }
    }

    private var grantWatch: Timer?
    private var activeObserver: NSObjectProtocol?

    var connectors: [PrimTool] {
        HostUI.accountConnectors(catalog.registry.tools)
    }

    var current: PrimTool? {
        connectors.first(where: { $0.name == selected })
    }

    init() {
        catalog = (try? HostCatalog.load()) ?? HostCatalog(registry: RegistryDoc(version: 1, types: [], tools: []))
        railHidden = UserDefaults.standard.bool(forKey: Self.railHiddenKey)
        railIcons = UserDefaults.standard.bool(forKey: Self.railIconsKey)
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tryRevealMessages()
        }
    }

    deinit {
        grantWatch?.invalidate()
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
    }

    func boot() {
        if catalog.registry.tools.isEmpty {
            catalog = (try? HostCatalog.load()) ?? catalog
        }
        door = .connectors
        let stored = UserDefaults.standard.string(forKey: Self.selectedKey) ?? ""
        let pick = connectors.first(where: { $0.name == stored && HostUI.isInHost($0) })
            ?? connectors.first(where: HostUI.isInHost)
            ?? HostUI.preferredConnector(catalog.registry.tools)
        selected = pick?.name
        if let pick { refresh(pick) }
        persistSelection()
        if !ChatDB.health() {
            askFDA = true
            beginWatchingGrant()
        }
    }

    func didSelectDoor(_ next: DeskDoor) {
        door = next
        if next == .connectors {
            tryRevealMessages()
        }
    }

    func didSelect(_ name: String?) {
        selected = name
        persistSelection()
        door = .connectors
        guard let name, let tool = connectors.first(where: { $0.name == name }) else {
            chat = nil
            return
        }
        refresh(tool)
    }

    func refresh(_ tool: PrimTool) {
        chat = HostUI.isInHost(tool) ? ChatDB.receive(limit: 32) : nil
    }

    func refreshCurrent() {
        if let tool = current { refresh(tool) }
    }

    func grantFDA() {
        ChatDB.openSettings()
        beginWatchingGrant()
    }

    /// After the existing FDA grant (or a new toggle), poll until chat.db opens and rows appear.
    func tryRevealMessages() {
        if selected == nil || current.map(HostUI.isInHost) != true {
            if let im = connectors.first(where: HostUI.isInHost) {
                selected = im.name
                persistSelection()
            }
        }
        refreshCurrent()
        guard ChatDB.health() else { return }
        askFDA = false
        grantWatch?.invalidate()
        grantWatch = nil
    }

    func beginWatchingGrant() {
        grantWatch?.invalidate()
        var ticks = 0
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] t in
            ticks += 1
            self?.tryRevealMessages()
            if ticks >= 180 {
                t.invalidate()
            }
        }
        grantWatch = timer
        RunLoop.main.add(timer, forMode: .common)
        tryRevealMessages()
    }

    /// Toolbar gear. FDA sheet wins — do not stack Settings on top of it.
    func showSettings() {
        guard !askFDA else { return }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func toggleRailHidden() {
        railHidden.toggle()
    }

    func toggleRailIcons() {
        railIcons.toggle()
        if railIcons { railHidden = false }
    }

    private func persistSelection() {
        UserDefaults.standard.set(selected ?? "", forKey: Self.selectedKey)
    }
}
