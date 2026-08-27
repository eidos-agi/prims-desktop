import Foundation
import PrimSimCore

public enum PackNew {
    public static func face(kind: String, title: String = "Untitled") -> String {
        """
        ---
        profile: \(kind)
        title: \(title)
        ---

        The pack stays the file.
        """
    }

    public static func files(kind: String) -> [String: String] {
        let index = face(kind: kind)
        switch kind {
        case "docket":
            return ["index.md": index, "docket.json": #"{"name":"Untitled"}"#, "tasks.jsonl": ""]
        case "deck":
            return ["index.md": index, "deck.json": #"{"name":"Untitled"}"#, "slides.jsonl": ""]
        case "invoice":
            return ["index.md": index, "lines.jsonl": ""]
        case "session":
            return ["index.md": index, "turns.jsonl": ""]
        case "arcade":
            return ["index.md": index, "arcade.json": #"{"system":"nes"}"#]
        case "opff":
            return ["index.md": index, "accounts.jsonl": "", "transactions.jsonl": ""]
        case "log":
            return ["index.md": index, "run.json": #"{"tool":"prim","status":"new"}"#, "events.jsonl": ""]
        case "opf":
            return ["index.md": index, "product.json": #"{"entities":[],"relationships":[]}"#]
        case "odwf":
            return ["index.md": index, "odwf.json": #"{"title":"Untitled","status":"scaffold"}"#]
        case "obf":
            return ["index.md": index, "book.json": #"{"title":"Untitled","pages":[]}"#]
        case "obif":
            return ["index.md": index, "brand.json": #"{"name":"Untitled"}"#]
        case "ocsf":
            return ["index.md": index, "ownership.jsonl": "", "entities.jsonl": "", "governance.jsonl": ""]
        default:
            return ["index.md": index]
        }
    }

    public static func make(kind: String) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-new-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        for (name, body) in files(kind: kind) {
            let url = tmp.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try body.data(using: .utf8)?.write(to: url)
        }
        let zip = tmp.appendingPathExtension("prim")
        try PackZip.zip(tmp, to: zip)
        return try Data(contentsOf: zip)
    }

    public static func inspect(_ data: Data) throws -> DetectedPrim {
        let zip = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-inspect-\(UUID().uuidString).prim")
        try data.write(to: zip)
        defer { try? FileManager.default.removeItem(at: zip) }
        return try Detect.open(zip)
    }
}
