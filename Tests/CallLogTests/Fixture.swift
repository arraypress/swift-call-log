//
//  Fixture.swift
//  CallLogTests
//
//  Created by David Sherlock on 2026.
//
//  A fixture home with stores in the real schemas' shape — every person,
//  number and word in them invented. Numbers come from Ofcom's drama range
//  (07700 900000–900999), which is never assigned.
//

import CallLog
import Foundation
import SQLite3

/// A throwaway home folder.
struct FixtureHome {

    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("call-log-tests-\(UUID().uuidString.prefix(8))")
    var locations: CallLocations { CallLocations(home: root) }
    var store: CallLogStore { CallLogStore(locations: locations) }

    init() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    /// Runs SQL against a new database at `url`, in WAL mode like the real stores.
    ///
    /// - Parameter keepWAL: leave the last statements in the -wal file, the
    ///   way a live store holds its recent rows, instead of checkpointing.
    func database(_ url: URL, _ statements: [String], walOnly: [String] = [], blobs: [(sql: String, data: [Data])] = []) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw FixtureError.sqlite("open") }
        defer { sqlite3_close(db) }
        try exec(db, "PRAGMA journal_mode=WAL")
        for statement in statements { try exec(db, statement) }
        for (sql, data) in blobs {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw FixtureError.sqlite(sql) }
            for (index, blob) in data.enumerated() {
                _ = blob.withUnsafeBytes { raw in
                    sqlite3_bind_blob(statement, Int32(index + 1), raw.baseAddress, Int32(blob.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
            }
            let step = sqlite3_step(statement)
            sqlite3_finalize(statement)
            guard step == SQLITE_DONE else { throw FixtureError.sqlite(sql) }
        }
        try exec(db, "PRAGMA wal_checkpoint(TRUNCATE)")
        try exec(db, "PRAGMA wal_autocheckpoint=0")
        for statement in walOnly { try exec(db, statement) }
    }

    private func exec(_ db: OpaquePointer?, _ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &message) == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "?"
            sqlite3_free(message)
            throw FixtureError.sqlite("\(sql): \(text)")
        }
    }

    // MARK: The call store

    static let callColumns = """
        Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZANSWERED INTEGER, ZAUTOANSWEREDREASON INTEGER,
        ZCALLDIRECTORYIDENTITYTYPE INTEGER, ZCALL_CATEGORY INTEGER, ZCALLTYPE INTEGER, ZCOMMUNICATIONTRUSTSCORE INTEGER,
        ZDISCONNECTED_CAUSE INTEGER, ZFACE_TIME_DATA INTEGER, ZFILTERED_OUT_REASON INTEGER, ZHANDLE_TYPE INTEGER,
        ZHASMESSAGE INTEGER, ZJUNKCONFIDENCE INTEGER, ZNUMBER_AVAILABILITY INTEGER, ZORIGINATED INTEGER,
        ZORIGINATINGUITYPE INTEGER, ZREAD INTEGER, ZSCREENSHARINGTYPE INTEGER, ZVERIFICATIONSTATUS INTEGER,
        ZWASEMERGENCYCALL INTEGER, ZINITIATOR INTEGER, ZDATE TIMESTAMP, ZDURATION FLOAT, ZADDRESS VARCHAR,
        ZISO_COUNTRY_CODE VARCHAR, ZLOCATION VARCHAR, ZNAME VARCHAR, ZORIGINATINGDEVICENAME VARCHAR,
        ZSERVICE_PROVIDER VARCHAR, ZUNIQUE_ID VARCHAR, ZCONVERSATIONID BLOB, ZPARTICIPANTGROUPUUID BLOB
        """

    /// A call row. `date` is Core Data seconds.
    static func callRow(_ key: Int, id: String, date: Double, duration: Double, originated: Bool, answered: Bool,
                        address: String, category: Int = 1, provider: String = "com.apple.FaceTime",
                        trust: Int = 8, ui: Int = 45, faceTimeData: Int = 0, numberAvailability: Int = 0,
                        hasMessage: Int = 0, initiator: String = "NULL", device: String = "NULL") -> String {
        """
        INSERT INTO ZCALLRECORD (Z_PK, Z_ENT, Z_OPT, ZANSWERED, ZCALL_CATEGORY, ZCALLTYPE, ZCOMMUNICATIONTRUSTSCORE,
          ZFACE_TIME_DATA, ZHANDLE_TYPE, ZNUMBER_AVAILABILITY, ZORIGINATED, ZORIGINATINGUITYPE, ZREAD, ZVERIFICATIONSTATUS,
          ZHASMESSAGE, ZINITIATOR, ZDATE, ZDURATION, ZADDRESS, ZSERVICE_PROVIDER, ZUNIQUE_ID, ZORIGINATINGDEVICENAME, ZISO_COUNTRY_CODE)
        VALUES (\(key), 2, 1, \(answered ? 1 : 0), \(category), 16, \(trust), \(faceTimeData), 2, \(numberAvailability),
          \(originated ? 1 : 0), \(ui), 1, 0, \(hasMessage), \(initiator), \(date), \(duration), '\(address)', '\(provider)', '\(id)', \(device), 'gb')
        """
    }

    /// Writes CallHistory.storedata with the given calls; the handle table
    /// and the many-to-many join are named as on macOS 27 unless told otherwise.
    func callHistory(_ rows: [String], walOnly: [String] = [], joins: [(call: Int, handle: Int)] = [],
                     handles: [(key: Int, value: String)] = [], joinPrefix: (Int, Int) = (2, 4)) throws {
        let table = "Z_\(joinPrefix.0)REMOTEPARTICIPANTHANDLES"
        var statements = [
            "CREATE TABLE ZCALLRECORD (\(Self.callColumns))",
            "CREATE TABLE ZHANDLE (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZTYPE INTEGER, ZNORMALIZEDVALUE VARCHAR, ZVALUE VARCHAR)",
            "CREATE TABLE \(table) (Z_\(joinPrefix.0)REMOTEPARTICIPANTCALLS INTEGER, Z_\(joinPrefix.1)REMOTEPARTICIPANTHANDLES INTEGER)",
        ]
        statements += handles.map { "INSERT INTO ZHANDLE VALUES (\($0.key), 4, 1, 2, '\($0.value)', '\($0.value)')" }
        statements += joins.map { "INSERT INTO \(table) VALUES (\($0.call), \($0.handle))" }
        try database(locations.callHistory, statements + rows, walOnly: walOnly)
    }
}

enum FixtureError: Error { case sqlite(String) }

/// Core Data seconds for a local date and time.
func coreData(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Double {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!.timeIntervalSinceReferenceDate
}

/// A call built in memory, for the statistics.
func call(_ id: String, _ date: Date, _ duration: Double, _ direction: CallDirection, _ status: CallStatus,
          with address: String, media: CallMedia = .audio, service: CallService = .facetime) -> Call {
    Call(id: id, date: date, duration: duration, direction: direction, status: status, media: media,
         service: service, provider: service == .phone ? "com.apple.Telephony" : "com.apple.FaceTime",
         address: address, participants: [Participant(address: address, kind: .phoneNumber)])
}
