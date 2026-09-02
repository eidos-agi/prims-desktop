import AppKit
import PrimMacCore
import PrimSimCore
import SwiftUI

/// Left rail of work. Accounts now; chats later. Collapse is icons (~56pt), not gone.
struct WorkRail: View {
    @EnvironmentObject private var desk: DeskModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if desk.railIcons {
                iconList
            } else {
                accountList
            }
            debugControl
        }
        .navigationSplitViewColumnWidth(
            min: desk.railIcons ? 56 : 240,
            ideal: desk.railIcons ? 56 : 252,
            max: desk.railIcons ? 68 : 280
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            if !desk.railIcons {
                Text("Accounts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            Button(action: desk.toggleRailIcons) {
                Image(systemName: desk.railIcons ? "chevron.right" : "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(desk.railIcons ? "Expand sidebar" : "Collapse sidebar")
            .accessibilityLabel(desk.railIcons ? "Expand sidebar" : "Collapse sidebar")
        }
        .padding(.horizontal, desk.railIcons ? 8 : 14)
        .padding(.vertical, 10)
    }

    private var accountList: some View {
        List(desk.connectors, selection: $desk.selected) { tool in
            AccountRow(tool: tool, preview: preview(for: tool))
                .tag(tool.name)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .contextMenu { overflow(for: tool) }
        }
        .listStyle(.sidebar)
        .onChange(of: desk.selected) { name in
            desk.didSelect(name)
        }
    }

    private var iconList: some View {
        VStack(spacing: 6) {
            ForEach(desk.connectors) { tool in
                let on = tool.name == desk.selected
                Button {
                    desk.didSelect(tool.name)
                } label: {
                    AccountAvatar(icon: ConnectorFace.icon(tool), on: on)
                }
                .buttonStyle(.plain)
                .help(ConnectorFace.title(tool))
                .accessibilityLabel(ConnectorFace.title(tool))
                .contextMenu { overflow(for: tool) }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
    }

    private var debugControl: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: desk.showDebug) {
                HStack(spacing: 8) {
                    Image(systemName: "ladybug")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: desk.railIcons ? 32 : 20, height: 20)
                    if !desk.railIcons {
                        Text("Debug")
                            .font(.system(size: 13, weight: .medium))
                        Spacer(minLength: 0)
                    }
                }
                .foregroundStyle(Ink.mute)
                .padding(.horizontal, desk.railIcons ? 8 : 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Debug")
            .accessibilityLabel("Debug")
        }
    }

    @ViewBuilder
    private func overflow(for _: PrimTool) -> some View {
        Button("Open Settings…") { desk.showSettings() }
    }

    private func preview(for tool: PrimTool) -> String {
        ConnectorFace.preview(tool, chat: HostUI.isInHost(tool) ? desk.chat : nil)
    }
}

struct AccountRow: View {
    @EnvironmentObject private var desk: DeskModel
    let tool: PrimTool
    let preview: String

    var body: some View {
        HStack(spacing: 10) {
            AccountAvatar(icon: ConnectorFace.icon(tool), on: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(ConnectorFace.title(tool))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Open Settings…") { desk.showSettings() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .accessibilityLabel(ConnectorFace.title(tool))
        .accessibilityValue(preview)
    }
}

struct AccountAvatar: View {
    let icon: String
    var on: Bool

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle().fill(on ? Ink.mark : Ink.mark.opacity(0.92))
            )
    }
}
