import AppKit
import PrimMacCore
import PrimSimCore
import SwiftUI

/// Standard Settings window. Connector path, FDA, and registry names live here — not on the stage.
struct DeskSettingsView: View {
    @EnvironmentObject private var desk: DeskModel
    @State private var account: String = ""

    var body: some View {
        TabView {
            accountsTab
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }
        }
        .frame(width: 520, height: 400)
        .onAppear {
            account = desk.selected
                ?? HostUI.preferredConnector(desk.catalog.registry.tools)?.name
                ?? ""
        }
    }

    private var accountsTab: some View {
        Form {
            Picker("Account", selection: $account) {
                ForEach(desk.connectors) { tool in
                    Text(ConnectorFace.title(tool)).tag(tool.name)
                }
            }
            if let tool = desk.connectors.first(where: { $0.name == account }) {
                Section("Connector") {
                    LabeledContent("Name", value: ConnectorFace.title(tool))
                    LabeledContent("Registry", value: tool.name)
                    LabeledContent("Status", value: status(tool))
                }
                if HostUI.isInHost(tool) {
                    Section("Messages") {
                        LabeledContent("Source") {
                            Text(ChatDB.path)
                                .textSelection(.enabled)
                                .font(.callout)
                        }
                        LabeledContent("Readable", value: ChatDB.health() ? "Yes" : "No")
                        if !ChatDB.health() {
                            Button("Grant Full Disk Access…") {
                                ChatDB.openSettings()
                            }
                        }
                        Button("Check again") {
                            desk.refresh(tool)
                        }
                    }
                } else {
                    Section {
                        Text("This account isn’t wired in the host yet. The registry entry is on this Mac.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func status(_ tool: PrimTool) -> String {
        if HostUI.isInHost(tool) {
            return ChatDB.health() ? "Connected" : "Needs Full Disk Access"
        }
        return "Registered"
    }
}
