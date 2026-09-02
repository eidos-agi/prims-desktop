import Foundation
import os

/// Append-only day files under `~/Library/Logs/Prims Desktop`.
/// Calendar date is America/Chicago (local if that zone is missing).
/// Old days are never deleted or rotated.
public enum DayLog {
    public static let folderName = "Prims Desktop"
    public static let chicagoID = "America/Chicago"

    public static var defaultDirectory: URL { Paths.debugLogs() }

    public static var timeZone: TimeZone {
        TimeZone(identifier: chicagoID) ?? .current
    }

    /// Shared process log. File on disk is the durable store.
    public static func event(_ name: String, _ detail: String = "") {
        let message = detail.isEmpty ? name : "\(name)  \(detail)"
        lock.lock()
        defer { lock.unlock() }
        do {
            _ = try Store(directory: defaultDirectory).append(message)
        } catch {
            osLog.error("day-file write failed: \(error.localizedDescription, privacy: .public)")
        }
        osLog.notice("\(message, privacy: .public)")
    }

    public struct Store: Sendable {
        public let directory: URL

        public init(directory: URL) {
            self.directory = directory
        }

        public func fileName(for date: Date) -> String {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = DayLog.timeZone
            let c = cal.dateComponents([.year, .month, .day], from: date)
            let y = c.year ?? 0
            let m = c.month ?? 0
            let d = c.day ?? 0
            return String(format: "%04d-%02d-%02d.log", y, m, d)
        }

        public func url(for date: Date = Date()) -> URL {
            directory.appendingPathComponent(fileName(for: date))
        }

        public func format(_ message: String, at date: Date) -> String {
            "\(stamp(date))  \(message)\n"
        }

        @discardableResult
        public func append(_ message: String, at date: Date = Date()) throws -> URL {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let dest = url(for: date)
            let data = Data(format(message, at: date).utf8)
            if FileManager.default.fileExists(atPath: dest.path) {
                let handle = try FileHandle(forWritingTo: dest)
                defer { try? handle.close() }
                _ = try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.synchronize()
            } else {
                try data.write(to: dest, options: .withoutOverwriting)
            }
            return dest
        }

        public func read(for date: Date = Date()) -> String {
            (try? String(contentsOf: url(for: date), encoding: .utf8)) ?? ""
        }

        public func existingDayFiles() -> [URL] {
            let found = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            return (found ?? [])
                .filter { $0.pathExtension == "log" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        private func stamp(_ date: Date) -> String {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime]
            fmt.timeZone = DayLog.timeZone
            return fmt.string(from: date)
        }
    }

    private static let lock = NSLock()
    private static let osLog = Logger(subsystem: ProductIdentity.bundleIdentifier, category: "debug")
}
