import Foundation
import PrimMacCore

/// In-app spawn only. A shell-exec'd helper is TCC client_type 1 and does
/// not inherit the app's FDA. PATH must exec Contents/MacOS/Prim. See scripts/TCC.md.

var healthOnly = false
var limit = 5

let args = Array(CommandLine.arguments.dropFirst())
var i = 0
while i < args.count {
    let arg = args[i]
    if arg == "--health" {
        healthOnly = true
        i += 1
        continue
    }
    if arg == "--limit" {
        i += 1
        if i < args.count, let n = Int(args[i]), n > 0 {
            limit = n
        }
        i += 1
        continue
    }
    i += 1
}

func emit(_ obj: [String: Any], status: Int32) -> Never {
    let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    if let data = try? JSONSerialization.data(withJSONObject: obj, options: opts),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    } else {
        fputs("{\"ok\": false, \"error\": \"JSON serialization failed\"}\n", stderr)
        exit(1)
    }
    exit(status)
}

if healthOnly {
    if ChatDB.health() {
        emit([
            "ok": true,
            "health": "chat.db readable",
            "source": ChatDB.path,
        ], status: 0)
    }
    emit([
        "ok": false,
        "error": ProductIdentity.fdaNote,
        "source": ChatDB.path,
    ], status: 2)
}

let received = ChatDB.receive(limit: limit)
if !received.ok {
    emit([
        "ok": false,
        "error": ProductIdentity.fdaNote,
        "source": ChatDB.path,
    ], status: 2)
}

var slimRows: [[String: Any]] = []
for msg in received.messages {
    var slim: [String: Any] = [
        "ROWID": msg.rowid,
        "is_from_me": msg.fromMe,
        "text": msg.text.count > 240 ? String(msg.text.prefix(240)) + "…" : msg.text,
    ]
    if let date = msg.date {
        slim["date"] = ISO8601DateFormatter().string(from: date)
    }
    slimRows.append(slim)
}

emit([
    "ok": true,
    "health": "chat.db readable",
    "source": ChatDB.path,
    "limit": limit,
    "count": slimRows.count,
    "messages": slimRows,
    "note": received.note,
], status: 0)
