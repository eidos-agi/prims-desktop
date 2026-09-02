import AppKit
import PrimMacCore
import PrimSimCore
import SwiftUI

/// The thing you use. Transcript / empty state, never a grouped settings form.
struct StageView: View {
    @EnvironmentObject private var desk: DeskModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if desk.door == .chat {
                ComposerStub()
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(desk.door.title)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            AccountAvatar(icon: headerIcon, on: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: 16, weight: .semibold))
                Text(headerStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var headerIcon: String {
        switch desk.door {
        case .viewer: return DeskDoor.viewer.icon
        case .chat: return DeskDoor.chat.icon
        case .connectors:
            if let tool = desk.current { return ConnectorFace.icon(tool) }
            return DeskDoor.connectors.icon
        }
    }

    private var headerTitle: String {
        switch desk.door {
        case .viewer: return "Viewer"
        case .chat: return "Chat"
        case .connectors:
            if let tool = desk.current { return ConnectorFace.title(tool) }
            return "Connectors"
        }
    }

    private var headerStatus: String {
        switch desk.door {
        case .viewer: return "Open pack"
        case .chat: return "Directs the open pack"
        case .connectors:
            if let tool = desk.current { return statusLine(tool) }
            return "Mac connectors"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch desk.door {
        case .viewer:
            EmptyStage(
                icon: DeskDoor.viewer.icon,
                title: "Viewer",
                detail: "Open a .prim pack. Double-click lands here."
            )
        case .connectors:
            connectorsStage
        case .chat:
            EmptyStage(
                icon: DeskDoor.chat.icon,
                title: "Chat",
                detail: "Chat directs the open pack. Messages live under Connectors."
            )
        }
    }

    @ViewBuilder
    private var connectorsStage: some View {
        if let tool = desk.current {
            if HostUI.isInHost(tool) {
                iMessageStage
            } else {
                EmptyStage(
                    icon: ConnectorFace.icon(tool),
                    title: ConnectorFace.title(tool),
                    detail: "This account isn’t wired yet. Connector details live in Settings."
                )
            }
        } else {
            EmptyStage(
                icon: "link",
                title: "Connectors",
                detail: "iMessage is the local Messages connector on this Mac."
            )
        }
    }

    @ViewBuilder
    private var iMessageStage: some View {
        if !ChatDB.health() {
            EmptyStage(
                icon: "message.fill",
                title: "See your messages",
                detail: ProductIdentity.fdaNote
            ) {
                Button("Grant Full Disk Access…") { desk.grantFDA() }
                    .keyboardShortcut(.defaultAction)
            }
        } else if let chat = desk.chat, chat.ok, !chat.messages.isEmpty {
            MessageTranscript(messages: chat.messages)
        } else {
            EmptyStage(
                icon: "message.fill",
                title: "Start here",
                detail: "iMessage is connected. Recent messages will show up in this space."
            )
        }
    }

    private func statusLine(_ tool: PrimTool) -> String {
        if HostUI.isInHost(tool) {
            if !ChatDB.health() { return "Needs Full Disk Access" }
            if let chat = desk.chat, chat.ok, !chat.messages.isEmpty {
                return "\(chat.messages.count) recent"
            }
            return ConnectorFace.blurb(tool)
        }
        return "Not wired yet"
    }
}

struct MessageTranscript: View {
    let messages: [ChatDB.Message]

    private var ordered: [ChatDB.Message] {
        Array(messages.reversed())
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(ordered) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if let last = ordered.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatDB.Message

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 48) }
            VStack(alignment: message.fromMe ? .trailing : .leading, spacing: 4) {
                Text(message.fromMe ? "You" : "Them")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(bodyText)
                    .font(.system(size: 14))
                    .foregroundStyle(message.fromMe ? Ink.youInk : Color.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(message.fromMe ? Ink.youFill : Color(nsColor: .controlBackgroundColor))
                    )
                if let stamp = timeLabel {
                    Text(stamp)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            if !message.fromMe { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.fromMe ? "You" : "Them"): \(bodyText)")
    }

    private var bodyText: String {
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "No text" : text
    }

    private var timeLabel: String? {
        guard let date = message.date else { return nil }
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct EmptyStage<Action: View>: View {
    let icon: String
    let title: String
    let detail: String
    var action: () -> Action

    init(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Ink.mark)
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            action()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

extension EmptyStage where Action == EmptyView {
    init(icon: String, title: String, detail: String) {
        self.init(icon: icon, title: title, detail: detail) { EmptyView() }
    }
}

/// Fixed bottom bar. Placeholder only — do not wire a model.
struct ComposerStub: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Chat coming", text: .constant(""))
                    .textFieldStyle(.plain)
                    .disabled(true)
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Composer. Chat coming")
        .accessibilityHint("Chat is not available yet.")
    }
}
