import AppKit
import Combine
import PrimMacCore
import PrimSimCore
import SwiftUI

/// Shared desk state. Rail selection survives collapse; Settings does not replace the stage.
final class DeskModel: ObservableObject {
    private static let selectedKey = "desk.selected"
    private static let railHiddenKey = "desk.railHidden"
    private static let railIconsKey = "desk.railIcons"

    @Published var catalog: HostCatalog
    @Published var selected: String?
    @Published var chat: ChatDB.Receive?
    @Published var askFDA = false
    @Published var railHidden: Bool {
        didSet { UserDefaults.standard.set(railHidden, forKey: Self.railHiddenKey) }
    }
    @Published var railIcons: Bool {
        didSet { UserDefaults.standard.set(railIcons, forKey: Self.railIconsKey) }
    }

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
    }

    func boot() {
        if catalog.registry.tools.isEmpty {
            catalog = (try? HostCatalog.load()) ?? catalog
        }
        let stored = UserDefaults.standard.string(forKey: Self.selectedKey) ?? ""
        let pick = connectors.first(where: { $0.name == stored })
            ?? HostUI.preferredConnector(catalog.registry.tools)
        selected = pick?.name
        if let pick { refresh(pick) }
        persistSelection()
        if !ChatDB.health() { askFDA = true }
    }

    func didSelect(_ name: String?) {
        selected = name
        persistSelection()
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
        askFDA = false
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
