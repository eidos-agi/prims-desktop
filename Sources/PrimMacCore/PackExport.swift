import Foundation
import PrimSimCore

public enum PackExport {
    public static func zip(_ files: [String: Data]) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        for (name, body) in files {
            let url = tmp.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try body.write(to: url)
        }
        let dest = tmp.appendingPathExtension("prim")
        try PackZip.zip(tmp, to: dest)
        return try Data(contentsOf: dest)
    }

    public static func file(_ data: Data, named name: String) throws -> String {
        let zip = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-read-\(UUID().uuidString).prim")
        try data.write(to: zip)
        defer { try? FileManager.default.removeItem(at: zip) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-read-\(UUID().uuidString)", isDirectory: true)
        try PackZip.unzip(zip, into: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = Detect.file(named: name, in: root)
        return try String(contentsOf: url, encoding: .utf8)
    }

    public static func mutating(_ data: Data, file name: String, _ body: String) throws -> Data {
        let zip = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-mut-\(UUID().uuidString).prim")
        try data.write(to: zip)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prim-mut-\(UUID().uuidString)", isDirectory: true)
        try PackZip.unzip(zip, into: root)
        defer {
            try? FileManager.default.removeItem(at: zip)
            try? FileManager.default.removeItem(at: root)
        }
        let url = Detect.file(named: name, in: root)
        try body.write(to: url, atomically: true, encoding: .utf8)
        let dest = root.appendingPathExtension("prim")
        try PackZip.zip(root, to: dest)
        return try Data(contentsOf: dest)
    }
}
