import AppKit
import Foundation
import PrimMacCore
import PrimSimCore

enum ToolLaunch {
    struct Result {
        var note: String
        var proof: String
    }

    static func open(_ tool: PrimTool, pack: Data, name: String) -> Result {
        guard HostUI.isProcess(tool) else {
            return Result(note: "\(tool.name) is not a local process tool", proof: "")
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try pack.write(to: tmp)
        } catch {
            return Result(note: error.localizedDescription, proof: "")
        }
        if let app = appURL(tool) {
            NSWorkspace.shared.open([tmp], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            return Result(note: "Opened \(tool.name) locally.", proof: "")
        }
        if let bin = binaryURL(tool) {
            return run(bin: bin, packPath: tmp.path, toolName: tool.name)
        }
        return Result(note: "\(tool.bin ?? tool.name) is not installed locally", proof: "")
    }

    private static func run(bin: URL, packPath: String, toolName: String) -> Result {
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = [packPath]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
        } catch {
            return Result(note: error.localizedDescription, proof: "")
        }

        let stdout = readPipe(out)
        let stderr = readPipe(err)
        let deadline = Date().addingTimeInterval(20)
        while proc.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            return Result(
                note: "\(toolName) timed out",
                proof: "Spawned \(bin.path) and it did not exit in 20s."
            )
        }
        let proof = stdout().trimmingCharacters(in: .whitespacesAndNewlines)
        let errText = stderr().trimmingCharacters(in: .whitespacesAndNewlines)
        if proc.terminationStatus != 0 {
            let fail = [errText, proof].filter { !$0.isEmpty }.joined(separator: "\n")
            return Result(
                note: fail.isEmpty ? "\(toolName) exited \(proc.terminationStatus)" : "\(toolName) failed",
                proof: fail
            )
        }
        if proof.isEmpty {
            return Result(note: "Opened \(toolName) locally.", proof: errText)
        }
        return Result(note: "\(toolName) ran on this Mac", proof: proof)
    }

    private static func readPipe(_ pipe: Pipe) -> () -> String {
        let handle = pipe.fileHandleForReading
        let data = NSMutableData()
        let lock = NSLock()
        handle.readabilityHandler = { h in
            let chunk = h.availableData
            if chunk.isEmpty {
                h.readabilityHandler = nil
                return
            }
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }
        return {
            handle.readabilityHandler = nil
            lock.lock()
            defer { lock.unlock() }
            return String(data: data as Data, encoding: .utf8) ?? ""
        }
    }

    private static func appURL(_ tool: PrimTool) -> URL? {
        let names = [tool.bin, tool.name].compactMap { $0 }
        for name in names {
            let url = Paths.home().appendingPathComponent("Applications/\(name).app")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private static func binaryURL(_ tool: PrimTool) -> URL? {
        let names = [tool.bin, tool.name].compactMap { $0 }
        let roots = [
            ProductIdentity.helpersDirectory(),
            Paths.home().appendingPathComponent("repos-eidos-agi/prim-sim/.build/release"),
            Paths.home().appendingPathComponent("repos-eidos-agi/prim-sim/.build/debug"),
            Paths.home().appendingPathComponent(".local/bin"),
        ]
        for root in roots {
            for name in names {
                let url = root.appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: url.path) { return url }
            }
        }
        return nil
    }
}
