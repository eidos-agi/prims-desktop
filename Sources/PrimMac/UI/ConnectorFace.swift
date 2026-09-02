import PrimMacCore
import PrimSimCore
import SwiftUI

enum ConnectorFace {
    static func title(_ tool: PrimTool) -> String {
        if HostUI.isInHost(tool) { return "iMessage" }
        switch tool.name {
        case "opff-dally-receive": return "Dally"
        case "docket-webmcp": return "Docket"
        case Paseo.connectorName: return "Paseo"
        case "prim-viewer-webmcp": return "Viewer"
        default: return tool.name
        }
    }

    static func blurb(_ tool: PrimTool) -> String {
        if HostUI.isInHost(tool) { return "Messages on this Mac" }
        switch tool.name {
        case "opff-dally-receive": return "Personal finance"
        case "docket-webmcp": return "Execution queue"
        case Paseo.connectorName: return "Tenant catalog"
        case "prim-viewer-webmcp": return "Open pack viewer"
        default: return tool.direction
        }
    }

    static func icon(_ tool: PrimTool) -> String {
        if HostUI.isInHost(tool) { return "message.fill" }
        switch tool.name {
        case "opff-dally-receive": return "dollarsign.circle.fill"
        case "docket-webmcp": return "list.bullet.rectangle.fill"
        case Paseo.connectorName: return "circle.grid.3x3.fill"
        case "prim-viewer-webmcp": return "eye.fill"
        default: return "link"
        }
    }

    static func preview(_ tool: PrimTool, chat: ChatDB.Receive?) -> String {
        if HostUI.isInHost(tool) {
            if !ChatDB.health() { return "Needs access" }
            if let chat, chat.ok, let last = chat.messages.first {
                let text = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { return "Attachment" }
                return text
            }
            return blurb(tool)
        }
        if Paseo.isPaseo(tool) {
            let n = (try? Paseo.loadTenants())?.count ?? 0
            return n == 0 ? "Tenant catalog" : "\(n) cells"
        }
        return blurb(tool)
    }
}
