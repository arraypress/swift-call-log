//
//  StoreTests.swift
//  CallLogTests
//
//  Created by David Sherlock on 2026.
//

@testable import CallLog
import Foundation
import Testing

@Suite(.serialized)
struct StoreTests {

    @Test func callsAreDecodedNewestFirstWithParticipants() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.callHistory(
            [
                FixtureHome.callRow(1, id: "A", date: coreData(2026, 10, 1, 9), duration: 600, originated: false, answered: true,
                                    address: "+447700900001", faceTimeData: 1_000_000, hasMessage: 0),
                FixtureHome.callRow(2, id: "B", date: coreData(2026, 10, 2, 9), duration: 0, originated: false, answered: false,
                                    address: "+447700900002", trust: 4, numberAvailability: 1, hasMessage: 1),
                FixtureHome.callRow(3, id: "C", date: coreData(2026, 10, 3, 9), duration: 0, originated: true, answered: false,
                                    address: "+447700900001", category: 2, ui: 14, device: "'Test iPhone'"),
            ],
            joins: [(1, 10), (2, 11), (3, 10), (3, 12)],
            handles: [(10, "+447700900001"), (11, "+447700900002"), (12, "+447700900003")]
        )
        let calls = try home.store.calls()
        #expect(calls.map(\.id) == ["C", "B", "A"])
        let group = calls[0]
        #expect(group.direction == .outgoing && group.status == .cancelled && group.media == .video)
        #expect(group.participants.map(\.address) == ["+447700900001", "+447700900003"])
        #expect(group.originatingUI == "faceTimeRecents" && group.device == "Test iPhone")
        let missed = calls[1]
        #expect(missed.status == .missed && missed.trust == .unknown && missed.callerID == .blocked && missed.hasMessage)
        let answered = calls[2]
        #expect(answered.status == .answered && answered.duration == 600 && answered.bytesUsed == 1_000_000)
        #expect(answered.trust == .contact && answered.service == .facetime && answered.countryCode == "gb")
        // Columns this fixture lacks come back nil, not as a failed query.
        #expect(answered.reminderID == nil && answered.junkCategory == nil)
    }

    /// The live store keeps its recent rows in the -wal for weeks: they must
    /// be read, and nothing may be left beside the store.
    @Test func rowsOnlyInTheWriteAheadLogAreRead() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.callHistory(
            [FixtureHome.callRow(1, id: "OLD", date: coreData(2026, 8, 1), duration: 60, originated: true, answered: false, address: "+447700900001")],
            walOnly: [FixtureHome.callRow(2, id: "NEW", date: coreData(2026, 10, 20), duration: 60, originated: true, answered: false, address: "+447700900001")]
        )
        let folder = home.locations.callHistory.deletingLastPathComponent()
        let before = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(before.contains("CallHistory.storedata-wal"))
        #expect(try home.store.calls().map(\.id) == ["NEW", "OLD"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == before)
    }

    /// Core Data names the join table after entity numbers; a model with one
    /// more entity renames it.
    @Test func renamedJoinTableIsFound() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.callHistory(
            [FixtureHome.callRow(1, id: "A", date: coreData(2026, 10, 1), duration: 5, originated: true, answered: false, address: "")],
            joins: [(1, 7), (1, 8)], handles: [(7, "a@example.com"), (8, "+447700900009")], joinPrefix: (3, 5)
        )
        let call = try #require(try home.store.calls().first)
        #expect(call.participants.map(\.address) == ["a@example.com", "+447700900009"])
        #expect(call.address == "a@example.com")
    }

    @Test func refusalAndAbsenceAreTold() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        #expect(throws: CallLogError.noStore(home.locations.callHistory.path)) { try home.store.calls() }
        try home.callHistory([])
        let folder = home.locations.callHistory.deletingLastPathComponent().path
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder) }
        #expect(throws: CallLogError.needsFullDiskAccess(home.locations.callHistory.path)) { try home.store.calls() }
    }

    @Test func messagesCarryTranscriptsAndFiles() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        let live = UUID(), deleted = UUID(), sidecar = UUID(), callID = UUID()
        let blob = { (uuid: UUID) in withUnsafeBytes(of: uuid.uuid) { Data($0) } }
        let transcript = TranscriptDecoding.archive([TranscriptSegment(text: "Your parcel is waiting.", confidence: 12)])
        try home.database(home.locations.messages, [
            """
            CREATE TABLE ZSTOREDMESSAGE (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZISREAD INTEGER, ZISSENSITIVE INTEGER,
              ZMAILBOXTYPE INTEGER, ZMESSAGETYPE INTEGER, ZTRANSCRIPTIONSTATUS INTEGER, ZDATECREATED TIMESTAMP, ZDATEDELETED TIMESTAMP,
              ZDURATION FLOAT, ZFILETYPE VARCHAR, ZFROM VARCHAR, ZPROVIDER VARCHAR, ZCALLUUID BLOB, ZRECORDUUID BLOB, ZTRANSCRIPT BLOB)
            """,
        ], blobs: [
            ("INSERT INTO ZSTOREDMESSAGE VALUES (1, 1, 1, 0, 0, 0, 0, 3, \(coreData(2026, 10, 5)), NULL, 34, 'MOV', '+447700900004', 'com.apple.coretelephony', ?, ?, ?)",
             [blob(callID), blob(live), transcript]),
            ("INSERT INTO ZSTOREDMESSAGE VALUES (2, 1, 1, 1, 0, 2, 0, 3, \(coreData(2026, 10, 4)), \(coreData(2026, 10, 6)), 4, NULL, '+447700900005', 'com.apple.coretelephony', NULL, ?, NULL)",
             [blob(deleted)]),
            ("INSERT INTO ZSTOREDMESSAGE VALUES (3, 1, 1, 1, 0, 1, 0, 3, \(coreData(2026, 10, 3)), NULL, 9, 'MOV', '+447700900006', 'com.apple.telephonyutilities.callservicesd.FaceTimeProvider', NULL, ?, NULL)",
             [blob(sidecar)]),
        ])
        for (id, withPlist) in [(live, false), (sidecar, true)] {
            let folder = home.locations.messageAssets.appendingPathComponent(String(id.uuidString.prefix(2)))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("audio".utf8).write(to: folder.appendingPathComponent("\(id.uuidString).MOV"))
            if withPlist {
                try TranscriptDecoding.archive([TranscriptSegment(text: "From the sidecar.")]).write(to: folder.appendingPathComponent("\(id.uuidString).plist"))
            }
        }
        let messages = try home.store.messages()
        #expect(messages.map(\.id) == [live.uuidString, deleted.uuidString, sidecar.uuidString])
        let first = messages[0]
        #expect(first.kind == "voicemail" && first.service == .phone && first.mailbox == .inbox && !first.read)
        #expect(first.transcript == "Your parcel is waiting." && first.callID == callID.uuidString)
        #expect(first.file?.hasSuffix("\(live.uuidString).MOV") == true)
        #expect(messages[1].deleted != nil && messages[1].file == nil && messages[1].mailbox == .trash)
        #expect(messages[2].transcript == "From the sidecar." && messages[2].service == .facetime && messages[2].mailbox == .junk)
        #expect(try home.store.message(id: sidecar.uuidString.lowercased()).id == sidecar.uuidString)
        #expect(throws: CallLogError.notFound("nope")) { try home.store.message(id: "nope") }
    }

    @Test func linksAndBlockList() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.database(home.locations.links, [
            """
            CREATE TABLE ZCONVERSATIONLINK (Z_PK INTEGER PRIMARY KEY, ZACTIVATED INTEGER, ZDELETEREASON INTEGER, ZLIFETIMETYPE INTEGER,
              ZORIGINATORHANDLE INTEGER, ZCREATIONDATE TIMESTAMP, ZDELETIONDATE TIMESTAMP, ZEXPIRATIONDATE TIMESTAMP, ZNAME VARCHAR,
              ZPSEUDONYM VARCHAR, ZPRIVATEKEY BLOB, ZPUBLICKEY BLOB)
            """,
            "CREATE TABLE ZHANDLE (Z_PK INTEGER PRIMARY KEY, ZINVITEDCONVERSATIONLINK INTEGER, ZORIGINATORCONVERSATIONLINK INTEGER, ZVALUE VARCHAR)",
            "INSERT INTO ZCONVERSATIONLINK VALUES (1, 1, 0, 0, 1, \(coreData(2026, 9, 1)), NULL, \(coreData(2027, 9, 1)), 'Book club', 'p123', x'00', x'01')",
            "INSERT INTO ZCONVERSATIONLINK VALUES (2, 0, 1, 0, 1, \(coreData(2026, 8, 1)), \(coreData(2026, 8, 2)), NULL, NULL, 'p456', x'00', x'01')",
            "INSERT INTO ZHANDLE VALUES (1, NULL, 1, 'me@example.com')",
            "INSERT INTO ZHANDLE VALUES (2, 1, NULL, '+447700900007')",
        ])
        let links = try home.store.links()
        #expect(links.map(\.name) == ["Book club", nil])
        #expect(links[0].activated && links[0].originator == "me@example.com" && links[0].invited == ["+447700900007"])
        #expect(links[1].deleted != nil && links[1].invited.isEmpty)

        #expect(try home.store.blocked().isEmpty)
        try FileManager.default.createDirectory(at: home.locations.blockList.deletingLastPathComponent(), withIntermediateDirectories: true)
        let preferences: [String: Any] = ["__kCMFBlockListStoreTopLevelKey": [
            "__kCMFBlockListStoreRevisionKey": 3,
            "__kCMFBlockListStoreArrayKey": [["__kCMFItemTypeKey": 0, "__kCMFItemPhoneNumberUnformattedKey": "+447700900008",
                                              "__kCMFItemPhoneNumberCountryCodeKey": "gb"]],
        ] as [String: Any]]
        try PropertyListSerialization.data(fromPropertyList: preferences, format: .binary, options: 0).write(to: home.locations.blockList)
        #expect(try home.store.blocked().map(\.value) == ["+447700900008"])
        #expect(try home.store.blockListRevision() == 3)
    }
}
