#!/usr/bin/env swift
//
// imessage-chatdb-receive — Prim Tool wrapper around chatdb-extract.
// Does not decode attributedBody. Exec the existing extractor.
//
// Usage:
//   imessage-chatdb-receive --health
//   imessage-chatdb-receive --limit N
//   imessage-chatdb-receive [pack-path]   # ToolLaunch argv[1]; ignored
//

import Foundation

let FDA_NOTE = """
Cannot open chat.db. Grant Full Disk Access to chatdb-extract \
(System Settings → Privacy & Security → Full Disk Access), then re-run. \
Do not grant it to a helper. Grant Full Disk Access to Prims Desktop and/or prims-desktop.
"""

var healthOnly = false
var limit: Int = 5

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
    // Pack path from ToolLaunch, or unknown flag: ignore.
    i += 1
}

func extractURL() -> URL? {
    let fm = FileManager.default
    let argv0 = URL(fileURLWithPath: CommandLine.arguments[0])
    let candidates = [
        argv0.deletingLastPathComponent().appendingPathComponent("chatdb-extract"),
        fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/chatdb-extract"),
    ]
    return candidates.first { fm.isExecutableFile(atPath: $0.path) }
}

func runExtract(_ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
    guard let bin = extractURL() else {
        return (127, "", "chatdb-extract is not installed in ~/.local/bin")
    }
    let proc = Process()
    proc.executableURL = bin
    proc.arguments = arguments
    let out = Pipe()
    let err = Pipe()
    proc.standardOutput = out
    proc.standardError = err
    do {
        try proc.run()
        proc.waitUntilExit()
    } catch {
        return (1, "", error.localizedDescription)
    }
    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (proc.terminationStatus, stdout, stderr)
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
    let result = runExtract(["--health"])
    if result.status == 0 {
        emit([
            "ok": true,
            "health": "chat.db readable",
            "source": NSHomeDirectory() + "/Library/Messages/chat.db",
            "bin": extractURL()?.path ?? "chatdb-extract",
        ], status: 0)
    }
    let err = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    emit([
        "ok": false,
        "error": err.isEmpty ? FDA_NOTE : "\(err)\n\(FDA_NOTE)",
        "source": NSHomeDirectory() + "/Library/Messages/chat.db",
    ], status: result.status == 0 ? 1 : result.status)
}

let result = runExtract(["--limit", String(limit)])
if result.status != 0 {
    let err = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    let out = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let detail = [err, out].filter { !$0.isEmpty }.joined(separator: "\n")
    emit([
        "ok": false,
        "error": detail.isEmpty ? FDA_NOTE : "\(detail)\n\(FDA_NOTE)",
        "source": NSHomeDirectory() + "/Library/Messages/chat.db",
    ], status: result.status)
}

var slimRows: [[String: Any]] = []
if let data = result.stdout.data(using: .utf8),
   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
   let messages = obj["messages"] as? [[String: Any]] {
    for row in messages {
        var slim: [String: Any] = [:]
        if let v = row["ROWID"] { slim["ROWID"] = v }
        if let v = row["is_from_me"] { slim["is_from_me"] = v }
        if let v = row["date"] { slim["date"] = v }
        let text = (row["text"] as? String)
            ?? (row["attributed_body_text"] as? String)
            ?? ""
        let clipped = text.count > 240 ? String(text.prefix(240)) + "…" : text
        slim["text"] = clipped
        slimRows.append(slim)
    }
}

emit([
    "ok": true,
    "health": "chat.db readable",
    "source": NSHomeDirectory() + "/Library/Messages/chat.db",
    "limit": limit,
    "count": slimRows.count,
    "messages": slimRows,
], status: 0)
