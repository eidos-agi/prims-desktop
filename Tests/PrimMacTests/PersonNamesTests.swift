import Foundation
import PrimMacCore
import XCTest

final class PersonNamesTests: XCTestCase {
    func testPersonJSONEmailAndPhoneMatch() throws {
        let tmp = try seedPrimsRoot()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let index = PersonNames.load(from: tmp)

        let incomingEmail = ChatDB.Message(
            rowid: 1,
            text: "Thanks Daniel. Would you mind sending it to my personal email?",
            fromMe: false,
            date: nil,
            identifier: "joshuadula98@gmail.com"
        )
        XCTAssertEqual(index.label(for: incomingEmail), "Joshua Bryan Dula")
        XCTAssertNotEqual(index.label(for: incomingEmail), "Them")

        let secondEmail = ChatDB.Message(
            rowid: 2,
            text: "We're launching our AI services",
            fromMe: false,
            date: nil,
            identifier: "josh@geewhizstudio.com"
        )
        XCTAssertEqual(index.label(for: secondEmail), "Joshua Bryan Dula")

        let incomingPhone = ChatDB.Message(
            rowid: 3,
            text: "And, inadvertently",
            fromMe: false,
            date: nil,
            identifier: "555-555-0123"
        )
        XCTAssertEqual(index.label(for: incomingPhone), "Joshua Bryan Dula")

        let incomingE164 = ChatDB.Message(
            rowid: 4,
            text: "hey",
            fromMe: false,
            date: nil,
            identifier: "+1 (555) 555-0123"
        )
        XCTAssertEqual(index.label(for: incomingE164), "Joshua Bryan Dula")

        let fromMe = ChatDB.Message(
            rowid: 5,
            text: "Hey Josh, just emailed you",
            fromMe: true,
            date: nil,
            identifier: "joshuadula98@gmail.com"
        )
        XCTAssertEqual(index.label(for: fromMe), "You")

        let unknownNamed = ChatDB.Message(
            rowid: 6,
            text: "hello",
            fromMe: false,
            date: nil,
            identifier: "+19998887777",
            displayName: "Alex"
        )
        XCTAssertEqual(index.label(for: unknownNamed), "Alex")

        let unknownId = ChatDB.Message(
            rowid: 7,
            text: "hello",
            fromMe: false,
            date: nil,
            identifier: "+19998887777"
        )
        XCTAssertEqual(index.label(for: unknownId), "+19998887777")

        let unknown = ChatDB.Message(rowid: 8, text: "hello", fromMe: false, date: nil)
        XCTAssertEqual(index.label(for: unknown), "Them")
    }

    func testDisplayNameIsTheShortLabelWhenPresent() throws {
        let withShort = Data("""
        {
          "id": "josh-dula",
          "profile": "person",
          "name": "Joshua Bryan Dula",
          "display_name": "Josh",
          "phones": ["+15555550123"],
          "emails": ["joshuadula98@gmail.com"],
          "relationship": "colleague",
          "source": "seed",
          "added": "2026-08-27"
        }
        """.utf8)
        let person = try XCTUnwrap(PersonNames.parsePersonJSON(withShort))
        XCTAssertEqual(person.label, "Josh")
        XCTAssertTrue(person.matches("joshuadula98@gmail.com"))
        XCTAssertTrue(person.matches("+15555550123"))

        let nameOnly = Data("""
        {
          "id": "josh-dula",
          "profile": "person",
          "name": "Joshua Bryan Dula",
          "phones": ["+15555550123"],
          "emails": ["joshuadula98@gmail.com", "josh@geewhizstudio.com", "j.dula@example.com"]
        }
        """.utf8)
        let full = try XCTUnwrap(PersonNames.parsePersonJSON(nameOnly))
        XCTAssertEqual(full.label, "Joshua Bryan Dula")
        XCTAssertTrue(full.matches("j.dula@example.com"))
    }

    func testRelateFieldIsNotRequired() throws {
        let data = Data("""
        {
          "id": "josh-dula",
          "profile": "person",
          "name": "Joshua Bryan Dula",
          "phones": ["+15555550123"],
          "emails": ["joshuadula98@gmail.com"]
        }
        """.utf8)
        let person = try XCTUnwrap(PersonNames.parsePersonJSON(data))
        XCTAssertEqual(person.label, "Joshua Bryan Dula")
        XCTAssertNil((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["relate"])
    }

    func testLoadWalksPersonSlugsAndDirectPacksOnly() throws {
        let tmp = try seedPrimsRoot()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let index = PersonNames.load(from: tmp)
        XCTAssertEqual(index.people.count, 2, "josh-dula under person/ plus one direct pack")
        XCTAssertNotNil(index.person(matching: "joshuadula98@gmail.com"))
        XCTAssertNotNil(index.person(matching: "alex@example.com"))
        XCTAssertNil(index.person(matching: "ignored@example.com"), "must not walk sibling type folders")
    }

    func testStageViewUsesPersonNamesNotHardcodedThem() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stage = try String(
            contentsOf: root.appendingPathComponent("Sources/PrimMac/UI/StageView.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(
            stage.contains(#"message.fromMe ? "You" : "Them""#),
            "StageView still hardcodes You/Them"
        )
        XCTAssertTrue(stage.contains("PersonNames"), "StageView must resolve names via PersonNames")

        let names = try String(
            contentsOf: root.appendingPathComponent("Sources/PrimMacCore/PersonNames.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(names.contains("appendingPathComponent(\"person\""), "must walk Documents/Prims/person")
        XCTAssertTrue(names.contains("\"emails\""), "must match emails[]")
        XCTAssertTrue(names.contains("\"phones\""), "must match phones[]")
        XCTAssertFalse(names.contains("\"relate\""), "must not require incubating relate")

        let chatdb = try String(
            contentsOf: root.appendingPathComponent("Sources/PrimMacCore/ChatDB.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(chatdb.contains("public var identifier: String"), "ChatDB.Message dropped identifier")
        XCTAssertTrue(chatdb.contains("public var displayName: String"), "ChatDB.Message dropped displayName")
        XCTAssertTrue(chatdb.contains("LEFT JOIN handle"), "extractMessages must join handle")
        XCTAssertTrue(chatdb.contains("chat.display_name"), "extractMessages must read chat.display_name")
    }

    // MARK: - fixtures (real on-disk layout)

    private func seedPrimsRoot() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("prims-person-names-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let josh = tmp.appendingPathComponent("person/josh-dula", isDirectory: true)
        try FileManager.default.createDirectory(at: josh, withIntermediateDirectories: true)
        try indexMD(title: "Joshua Bryan Dula").write(
            to: josh.appendingPathComponent("index.md"),
            atomically: true,
            encoding: .utf8
        )
        try """
        {
          "id": "josh-dula",
          "profile": "person",
          "name": "Joshua Bryan Dula",
          "phones": ["+15555550123"],
          "emails": ["joshuadula98@gmail.com", "josh@geewhizstudio.com", "j.dula@example.com"],
          "relationship": "colleague",
          "source": "seed",
          "added": "2026-08-27"
        }
        """.write(to: josh.appendingPathComponent("person.json"), atomically: true, encoding: .utf8)

        let direct = tmp.appendingPathComponent("alex-rivera", isDirectory: true)
        try FileManager.default.createDirectory(at: direct, withIntermediateDirectories: true)
        try indexMD(title: "Alex Rivera").write(
            to: direct.appendingPathComponent("index.md"),
            atomically: true,
            encoding: .utf8
        )
        try """
        {
          "id": "alex-rivera",
          "profile": "person",
          "name": "Alex Rivera",
          "display_name": "Alex",
          "phones": [],
          "emails": ["alex@example.com"],
          "relationship": "",
          "source": "seed",
          "added": "2026-08-27"
        }
        """.write(to: direct.appendingPathComponent("person.json"), atomically: true, encoding: .utf8)

        let docket = tmp.appendingPathComponent("docket/ignored", isDirectory: true)
        try FileManager.default.createDirectory(at: docket, withIntermediateDirectories: true)
        try """
        {
          "id": "ignored",
          "profile": "docket",
          "name": "Ignored",
          "emails": ["ignored@example.com"],
          "phones": []
        }
        """.write(to: docket.appendingPathComponent("person.json"), atomically: true, encoding: .utf8)

        return tmp
    }

    private func indexMD(title: String) -> String {
        """
        ---
        profile: person
        title: \(title)
        ---

        The pack stays the file.
        """
    }
}
