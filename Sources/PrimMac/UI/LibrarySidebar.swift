import PrimMacCore
import PrimSimCore
import SwiftUI

struct LibrarySidebar: View {
    let catalog: HostCatalog
    let currentKind: String
    let currentTool: String
    var onType: (PrimType) -> Void
    var onTool: (PrimTool) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                block("Library", count: catalog.connectors().count) {
                    ForEach(catalog.connectors()) { tool in
                        toolRow(tool)
                    }
                }
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 16) {
                        block("Types", count: catalog.registry.types.count) {
                            ForEach(catalog.registry.types) { type in
                                row(
                                    title: type.name,
                                    sub: type.description,
                                    on: type.name == currentKind,
                                    dim: !currentKind.isEmpty && type.name != currentKind
                                ) { onType(type) }
                            }
                        }
                        block("Surfaces", count: catalog.surfaces().count) {
                            ForEach(catalog.surfaces()) { tool in
                                toolRow(tool)
                            }
                        }
                        if !catalog.hosts().isEmpty {
                            block("Hosts", count: catalog.hosts().count) {
                                ForEach(catalog.hosts()) { tool in
                                    row(title: tool.name, sub: tool.role, on: false, dim: true, action: nil)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Catalog")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Ink.faint)
                        .textCase(.uppercase)
                }
            }
            .padding(12)
        }
        .background(Ink.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Prims Desktop")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.paper)
            Text("library · document")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Ink.mute)
        }
    }

    private func block<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Ink.faint)
                    .textCase(.uppercase)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Ink.mute)
            }
            content()
        }
    }

    private func toolRow(_ tool: PrimTool) -> some View {
        let citesHere = HostUI.cites(tool, kind: currentKind)
        return row(
            title: tool.name,
            sub: HostUI.isInHost(tool)
                ? "iMessage · chat.db"
                : (Paseo.isPaseo(tool) ? "Paseo · tenant catalog" : tool.role),
            on: tool.name == currentTool,
            dim: !citesHere
        ) { onTool(tool) }
    }

    private func row(title: String, sub: String, on: Bool, dim: Bool, action: (() -> Void)?) -> some View {
        let body = VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(on ? Ink.gold : Ink.paper)
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(Ink.mute)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(on ? Ink.raise : Color.clear)
        .opacity(dim && !on ? 0.45 : 1)
        .contentShape(Rectangle())

        return Group {
            if let action {
                Button(action: action) { body }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
            } else {
                body
            }
        }
    }
}
