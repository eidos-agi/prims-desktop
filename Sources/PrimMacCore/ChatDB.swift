import AppKit
import Foundation
import SQLite3

/// In-process reader for `~/Library/Messages/chat.db`.
/// Decoder is the eidos-do-v1 `chatdb-extract.swift` attributedBody path
/// (NSUnarchiver / typedstream). Runs in the app or an embedded helper
/// so it inherits Prims Desktop FDA. Do not read chat.db from a loose bin.
public enum ChatDB {
    public static let path = NSHomeDirectory() + "/Library/Messages/chat.db"

    public static let fdaNote = ProductIdentity.fdaNote

    public struct Message: Sendable, Identifiable {
        public var id: Int64 { rowid }
        public var rowid: Int64
        public var text: String
        public var fromMe: Bool
        public var date: Date?
        /// `message.handle_id` → `handle.ROWID`. 0 when unset (typical for from-me).
        public var handleId: Int64 = 0
        /// `handle.id` — phone or email. Empty when there is no handle row.
        public var identifier: String = ""
        /// `chat.chat_identifier` via `chat_message_join`. Empty when unjoined.
        public var chatIdentifier: String = ""
        /// `chat.display_name`, else `message.cache_roomnames`. Empty if neither.
        public var displayName: String = ""
    }

    public struct Receive: Sendable {
        public var ok: Bool
        public var note: String
        public var messages: [Message]
    }

    /// macOS has no FDA popup. Open the Full Disk Access pane so the user can enable Prims Desktop.
    public static func openSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        ]
        for s in urls {
            if let url = URL(string: s), NSWorkspace.shared.open(url) { return }
        }
    }

    public static func health() -> Bool {
        guard let db = openDB() else { return false }
        sqlite3_close(db)
        return true
    }

    public static func receive(limit: Int = 8) -> Receive {
        let n = max(1, limit)
        guard let db = openDB() else {
            return Receive(ok: false, note: fdaNote, messages: [])
        }
        defer { sqlite3_close(db) }
        let rows = extractMessages(db: db, limit: n)
        var messages: [Message] = []
        messages.reserveCapacity(rows.count)
        for row in rows {
            let rowid = (row["ROWID"] as? Int64) ?? 0
            let text = (row["text"] as? String)
                ?? (row["attributed_body_text"] as? String)
                ?? ""
            let fromMe = ((row["is_from_me"] as? Int64) ?? 0) == 1
            var date: Date?
            if let raw = row["date"] as? Int64 {
                date = Date(timeIntervalSinceReferenceDate: Double(raw) / 1_000_000_000)
            }
            let handleId = (row["handle_id"] as? Int64) ?? 0
            let identifier = (row["identifier"] as? String) ?? ""
            let chatIdentifier = (row["chat_identifier"] as? String) ?? ""
            let chatDisplay = (row["display_name"] as? String) ?? ""
            let room = (row["cache_roomnames"] as? String) ?? ""
            let displayName = !chatDisplay.isEmpty ? chatDisplay : room
            messages.append(Message(
                rowid: rowid,
                text: text,
                fromMe: fromMe,
                date: date,
                handleId: handleId,
                identifier: identifier,
                chatIdentifier: chatIdentifier,
                displayName: displayName
            ))
        }
        if messages.isEmpty {
            return Receive(
                ok: true,
                note: "chat.db opened. No recent messages.",
                messages: []
            )
        }
        return Receive(
            ok: true,
            note: "\(messages.count) recent messages from chat.db",
            messages: messages
        )
    }

    private static func openDB() -> OpaquePointer? {
        var db: OpaquePointer?
        let url = "file:" + path + "?mode=ro"
        let rc = sqlite3_open_v2(url, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        if rc != SQLITE_OK {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        return db
    }

    /// Decode an NSAttributedString typedstream archive and return the plain text.
    /// Copied from eidos-do-v1/tools/chatdb-extract.swift — do not replace.
    private static func decodeAttributedBody(_ data: Data) -> String? {
        guard data.count > 15 else { return nil }
        let header = data.prefix(20)
        guard let magic = "streamtyped".data(using: .ascii),
              header.range(of: magic) != nil else { return nil }
        guard let obj = NSUnarchiver.unarchiveObject(with: data) else { return nil }
        guard let attrStr = obj as? NSAttributedString else { return nil }
        let str = attrStr.string
        if str.isEmpty { return nil }
        let cleaned = str.filter { $0 != "\u{FFFC}" && !$0.isWhitespace }
        return cleaned.isEmpty ? nil : str
    }

    /// attributedBody BLOB decode when `text` is NULL. Same message columns as
    /// chatdb-extract --limit, plus handle.id and chat via chat_message_join.
    private static func extractMessages(db: OpaquePointer, limit: Int) -> [[String: Any]] {
        let sql = """
            SELECT
                message.ROWID,
                message.guid,
                message.text,
                message.handle_id,
                message.date,
                message.date_read,
                message.is_from_me,
                message.is_read,
                message.cache_has_attachments,
                message.thread_originator_guid,
                message.associated_message_guid,
                message.associated_message_type,
                message.cache_roomnames,
                handle.id AS identifier,
                chat.chat_identifier,
                chat.display_name,
                message.attributedBody
            FROM message
            LEFT JOIN handle ON handle.ROWID = message.handle_id
            LEFT JOIN (
                SELECT message_id, MIN(chat_id) AS chat_id
                FROM chat_message_join
                GROUP BY message_id
            ) AS chat_message_join ON chat_message_join.message_id = message.ROWID
            LEFT JOIN chat ON chat.ROWID = chat_message_join.chat_id
            ORDER BY message.ROWID DESC
            LIMIT \(limit)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            let colCount = sqlite3_column_count(stmt)
            var attributedBodyIndex: Int32?
            for i: Int32 in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                if name == "attributedBody" {
                    attributedBodyIndex = i
                    continue
                }
                let type = sqlite3_column_type(stmt, i)
                switch type {
                case SQLITE_INTEGER:
                    row[name] = sqlite3_column_int64(stmt, i)
                case SQLITE_TEXT:
                    if let cStr = sqlite3_column_text(stmt, i) {
                        row[name] = String(cString: cStr)
                    }
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, i)
                default:
                    row[name] = NSNull()
                }
            }
            if row["text"] is NSNull, let blobIndex = attributedBodyIndex {
                if sqlite3_column_type(stmt, blobIndex) == SQLITE_BLOB,
                   let bytes = sqlite3_column_blob(stmt, blobIndex) {
                    let size = Int(sqlite3_column_bytes(stmt, blobIndex))
                    if size > 0 {
                        let data = Data(bytes: bytes, count: size)
                        if let decoded = decodeAttributedBody(data) {
                            row["attributed_body_text"] = decoded
                        }
                    }
                }
            }
            rows.append(row)
        }
        return rows
    }
}
