import AppKit
import PrimMacCore
import PrimSimCore
import SwiftUI

/// Left rail: exactly three doors. Connector accounts are Connectors content, not a fourth door.
struct WorkRail: View {
    @EnvironmentObject private var desk: DeskModel

    var body: some View {
        VStack(spacing: 0) {
            header
            doorList
            if desk.door == .connectors, !desk.railIcons {
                Divider()
                accountList
            }
            Spacer(minLength: 0)
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
                Text("Prims Desktop")
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

    private var doorList: some View {
        VStack(spacing: desk.railIcons ? 6 : 2) {
            ForEach(DeskDoor.allCases) { door in
                doorRow(door)
            }
        }
        .padding(.horizontal, desk.railIcons ? 10 : 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func doorRow(_ door: DeskDoor) -> some View {
        let on = desk.door == door
        Button {
            desk.didSelectDoor(door)
        } label: {
            if desk.railIcons {
                AccountAvatar(icon: door.icon, on: on)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: door.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 20)
                    Text(door.title)
                        .font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Color.primary.opacity(0.08) : Color.clear)
                )
            }
        }
        .buttonStyle(.plain)
        .help(door.title)
        .accessibilityLabel(door.title)
        .accessibilityAddTraits(on ? .isSelected : [])
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
