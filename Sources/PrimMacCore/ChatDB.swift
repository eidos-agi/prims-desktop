import AppKit
import Foundation
import SQLite3

/// In-process reader for `~/Library/Messages/chat.db`.
/// Decoder is the eidos-do-v1 `chatdb-extract.swift` attributedBody path
/// (NSUnarchiver / typedstream). Must run in `Contents/MacOS/Prim` (the
/// app bundle, TCC client_type 0) so it inherits the app's FDA. A helper
/// Mach-O exec'd from a shell is client_type 1 and stays locked. Do not
/// read chat.db from a loose bin. See scripts/TCC.md.
public enum ChatDB {
    public static let path = NSHomeDirectory() + "/Library/Messages/chat.db"

    public static let fdaNote = ProductIdentity.fdaNote

    public struct Message: Sendable, Identifiable {
        public var id: Int64 { rowid }
        public var rowid: Int64
        public var text: String
        public var fromMe: Bool
        public var date: Date?
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
            messages.append(Message(rowid: rowid, text: text, fromMe: fromMe, date: date))
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
        // Shell-exec of MacOS/Prim is TCC client_type 1. Only the LS-launched
        // app process (parent launchd) may open chat.db.
        guard ProcessEntry.isLaunchServicesAppProcess() else { return nil }
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

    /// attributedBody BLOB decode when `text` is NULL. Same SQL as chatdb-extract --limit.
    private static func extractMessages(db: OpaquePointer, limit: Int) -> [[String: Any]] {
        let baseColumns = """
            ROWID, guid, text, handle_id, date, date_read, is_from_me, is_read,
            cache_has_attachments, thread_originator_guid,
            associated_message_guid, associated_message_type, cache_roomnames
        """
        let sql = "SELECT \(baseColumns), attributedBody FROM message ORDER BY ROWID DESC LIMIT \(limit)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var rows: [[String: Any]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i: Int32 in 0..<13 {
                let name = String(cString: sqlite3_column_name(stmt, i))
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
            if row["text"] is NSNull {
                if sqlite3_column_type(stmt, 13) == SQLITE_BLOB,
                   let bytes = sqlite3_column_blob(stmt, 13) {
                    let size = Int(sqlite3_column_bytes(stmt, 13))
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
