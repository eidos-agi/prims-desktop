import Foundation
import PrimSimCore

/// Human names for chat rows. Reads prim.person packs on disk; not a contacts store.
///
/// Layout already on the Mac:
///   ~/Documents/Prims/person/<slug>/{index.md, person.json}
/// plus any prim.person pack sitting directly under ~/Documents/Prims.
/// person.json keys: name, display_name, phones[], emails[], id, profile,
/// relationship, source, added. Do not require incubating `relate`.
public enum PersonNames {
    public struct Person: Sendable, Equatable {
        public var name: String
        public var displayName: String
        public var emails: [String]
        public var phones: [String]

        public init(name: String, displayName: String = "", emails: [String] = [], phones: [String] = []) {
            self.name = name
            self.displayName = displayName
            self.emails = emails
            self.phones = phones
        }

        /// Short label: display_name when the pack uses it, else name.
        public var label: String {
            let short = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !short.isEmpty { return short }
            return name
        }

        public func matches(_ raw: String) -> Bool {
            let needle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if needle.isEmpty { return false }
            if emails.contains(where: { PersonNames.emailsEqual($0, needle) }) { return true }
            if phones.contains(where: { PersonNames.phonesEqual($0, needle) }) { return true }
            return false
        }
    }

    public struct Index: Sendable {
        public var people: [Person]

        public init(people: [Person]) {
            self.people = people
        }

        public func person(matching raw: String) -> Person? {
            people.first { $0.matches(raw) }
        }

        public func label(for message: ChatDB.Message) -> String {
            PersonNames.label(for: message, in: self)
        }
    }

    public static func load(from root: URL? = nil) -> Index {
        let base = root ?? Paths.prims()
        var people: [Person] = []
        people.append(contentsOf: loadSlugs(in: base.appendingPathComponent("person", isDirectory: true), requirePersonProfile: false))
        people.append(contentsOf: loadDirectPacks(in: base))
        return Index(people: dedupe(people))
    }

    public static func parsePersonJSON(_ data: Data) -> Person? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let profile = string(in: root, key: "profile"), profile != "person" {
            return nil
        }
        let emails = strings(in: root, key: "emails")
        let phones = strings(in: root, key: "phones")
        let name = string(in: root, key: "name") ?? ""
        let displayName = string(in: root, key: "display_name") ?? ""
        if name.isEmpty && displayName.isEmpty { return nil }
        if emails.isEmpty && phones.isEmpty { return nil }
        return Person(
            name: name.isEmpty ? displayName : name,
            displayName: displayName,
            emails: emails,
            phones: phones
        )
    }

    /// Incoming: prim.person match on identifier, else chat.display_name / identifier.
    /// Never "Them" for a known person. from-me is "You" (handle id is the other person).
    public static func label(for message: ChatDB.Message, in index: Index) -> String {
        if message.fromMe { return "You" }
        for key in [message.identifier, message.chatIdentifier] {
            if let person = index.person(matching: key) {
                return person.label
            }
        }
        for value in [message.displayName, message.identifier, message.chatIdentifier] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Them"
    }

    public static func emailsEqual(_ a: String, _ b: String) -> Bool {
        let left = normalizeEmail(a)
        let right = normalizeEmail(b)
        return !left.isEmpty && left == right
    }

    public static func phonesEqual(_ a: String, _ b: String) -> Bool {
        let da = digits(a)
        let db = digits(b)
        if da.isEmpty || db.isEmpty { return false }
        if da == db { return true }
        if da.count >= 10 && db.count >= 10 {
            return da.suffix(10) == db.suffix(10)
        }
        return false
    }

    // MARK: - disk

    /// ~/Documents/Prims/person/<slug>/ or person/<slug>.prim
    private static func loadSlugs(in personRoot: URL, requirePersonProfile: Bool) -> [Person] {
        children(of: personRoot).compactMap { child in
            pack(at: child, requirePersonProfile: requirePersonProfile)
        }
    }

    /// prim.person packs sitting directly under ~/Documents/Prims (not other type folders).
    private static func loadDirectPacks(in root: URL) -> [Person] {
        children(of: root).compactMap { child in
            if child.lastPathComponent == "person" { return nil }
            return pack(at: child, requirePersonProfile: true)
        }
    }

    private static func pack(at url: URL, requirePersonProfile: Bool) -> Person? {
        if url.pathExtension == "prim" {
            return person(fromPrim: url, requirePersonProfile: requirePersonProfile)
        }
        guard isDirectory(url) else { return nil }
        return person(fromUnpacked: url, requirePersonProfile: requirePersonProfile)
    }

    private static func person(fromUnpacked url: URL, requirePersonProfile: Bool) -> Person? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("person.json")) else {
            return nil
        }
        if requirePersonProfile, !isPersonPack(directory: url, json: data) {
            return nil
        }
        return parsePersonJSON(data)
    }

    private static func person(fromPrim url: URL, requirePersonProfile: Bool) -> Person? {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(
            "person-prim-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: dest) }
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            try PackZip.unzip(url, into: dest)
            let root = packRoot(in: dest)
            return person(fromUnpacked: root, requirePersonProfile: requirePersonProfile)
        } catch {
            return nil
        }
    }

    private static func packRoot(in dest: URL) -> URL {
        let direct = dest.appendingPathComponent("person.json")
        if FileManager.default.fileExists(atPath: direct.path) { return dest }
        let kids = children(of: dest).filter { isDirectory($0) }
        if kids.count == 1 { return kids[0] }
        return dest
    }

    private static func isPersonPack(directory: URL, json: Data) -> Bool {
        if let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
           let profile = string(in: obj, key: "profile"),
           profile == "person" {
            return true
        }
        return indexProfile(in: directory) == "person"
    }

    private static func indexProfile(in directory: URL) -> String? {
        let index = directory.appendingPathComponent("index.md")
        guard let text = try? String(contentsOf: index, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") {
            let raw = line.trimmingCharacters(in: .whitespaces)
            if raw.lowercased().hasPrefix("profile:") {
                return String(raw.dropFirst("profile:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func dedupe(_ people: [Person]) -> [Person] {
        var seen = Set<String>()
        var out: [Person] = []
        for person in people {
            let key = ([person.name.lowercased()]
                + person.emails.map(normalizeEmail)
                + person.phones.map(digits))
                .filter { !$0.isEmpty }
                .joined(separator: "|")
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            out.append(person)
        }
        return out
    }

    private static func normalizeEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func digits(_ raw: String) -> String {
        raw.filter(\.isNumber)
    }

    private static func string(in obj: [String: Any], key: String) -> String? {
        guard let value = obj[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func strings(in obj: [String: Any], key: String) -> [String] {
        if let value = obj[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        if let values = obj[key] as? [String] {
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}
