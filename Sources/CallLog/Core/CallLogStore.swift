//
//  CallLogStore.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  The calls, from CallHistory.storedata — the Core Data store callhistoryd
//  keeps for Phone, FaceTime and every CallKit app. Read from a private copy
//  (see DatabaseSnapshot); the live store is never opened.
//

import Foundation

/// A Mac's call history, read-only.
public struct CallLogStore: Sendable {

    /// Where each store is.
    public let locations: CallLocations

    public init(locations: CallLocations = CallLocations()) {
        self.locations = locations
    }

    /// Every call, newest first.
    public func calls() throws(CallLogError) -> [Call] {
        let snapshot = try DatabaseSnapshot(of: locations.callHistory)
        return try CallRows.calls(in: snapshot.database)
    }

    /// One call by its id.
    public func call(id: String) throws(CallLogError) -> Call {
        guard let call = try calls().first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            throw .notFound(id)
        }
        return call
    }
}

/// Turning ZCALLRECORD rows into calls.
enum CallRows {

    /// The record columns read, in order. A column an older or newer macOS
    /// lacks is read as NULL rather than failing the query.
    static let columns = [
        "Z_PK", "ZUNIQUE_ID", "ZDATE", "ZDURATION", "ZORIGINATED", "ZANSWERED", "ZCALL_CATEGORY", "ZCALLTYPE",
        "ZSERVICE_PROVIDER", "ZADDRESS", "ZNAME", "ZHANDLE_TYPE", "ZREAD", "ZLOCATION", "ZISO_COUNTRY_CODE",
        "ZORIGINATINGDEVICENAME", "ZFACE_TIME_DATA", "ZCOMMUNICATIONTRUSTSCORE", "ZVERIFICATIONSTATUS",
        "ZJUNKCONFIDENCE", "ZJUNKIDENTIFICATIONCATEGORY", "ZBLOCKEDBYEXTENSION", "ZBLOCKEDBYEXTENSIONNAME",
        "ZIDENTITYEXTENSION", "ZCALLDIRECTORYIDENTITYTYPE", "ZNUMBER_AVAILABILITY", "ZAUTOANSWEREDREASON",
        "ZHASMESSAGE", "ZDIDENABLETRANSLATION", "ZSCREENSHARINGTYPE", "ZWASEMERGENCYCALL", "ZORIGINATINGUITYPE",
        "ZDISCONNECTED_CAUSE", "ZFILTERED_OUT_REASON", "ZCONVERSATIONID", "ZPARTICIPANTGROUPUUID",
        "ZREMINDERUUID", "ZINITIATOR",
    ]

    static func calls(in database: SQLiteDatabase) throws(CallLogError) -> [Call] {
        let present = database.columns(of: "ZCALLRECORD")
        guard !present.isEmpty else { throw .unreadable("CallHistory.storedata", reason: "no ZCALLRECORD table") }
        let handles = try self.handles(in: database)
        let participants = try self.participants(in: database, handles: handles)
        let select = columns.map { present.contains($0) ? $0 : "NULL" }.joined(separator: ", ")
        var calls: [Call] = []
        try database.query("SELECT \(select) FROM ZCALLRECORD ORDER BY ZDATE DESC") { row in
            if let call = call(row, participants: participants, handles: handles) { calls.append(call) }
        }
        return calls
    }

    /// One row, or `nil` for one without an id or date.
    static func call(_ row: SQLiteDatabase.Row, participants: [Int: [Participant]], handles: [Int: Participant]) -> Call? {
        guard let key = row.integer(0), let id = row.text(1), let seconds = row.double(2) else { return nil }
        let duration = max(0, row.double(3) ?? 0)
        let originated = (row.integer(4) ?? 0) != 0
        let provider = row.text(8) ?? CallCodes.telephonyProvider
        var media = CallCodes.media(category: row.integer(6))
        if media == .unknown { media = CallCodes.media(callType: row.integer(7)) }
        let address = row.text(9)
        var people = participants[key] ?? []
        if people.isEmpty, let address {
            people = [Participant(address: address, kind: HandleKind(code: row.integer(11)) ?? .unknown, name: row.text(10))]
        }
        return Call(
            id: id,
            date: Date(timeIntervalSinceReferenceDate: seconds),
            duration: duration,
            direction: originated ? .outgoing : .incoming,
            status: CallCodes.status(duration: duration, originated: originated, answered: (row.integer(5) ?? 0) != 0),
            media: media,
            service: CallCodes.service(provider: provider),
            provider: provider,
            address: address ?? people.first?.address,
            participants: people,
            initiator: row.integer(37).flatMap { handles[$0] },
            read: (row.integer(12) ?? 1) != 0,
            location: row.text(13),
            countryCode: row.text(14)?.lowercased(),
            device: row.text(15),
            bytesUsed: row.integer(16).flatMap { $0 > 0 ? $0 : nil },
            trust: TrustScore(code: row.integer(17)),
            verification: VerificationStatus(code: row.integer(18)),
            junkConfidence: JunkConfidence(code: row.integer(19)),
            junkCategory: row.text(20),
            blockedByExtension: row.text(21),
            blockedByExtensionName: row.text(22),
            identityExtension: row.text(23),
            identityType: IdentityType(code: row.integer(24)),
            callerID: CallerIDAvailability(code: row.integer(25)),
            screened: (row.integer(26) ?? 0) != 0,
            hasMessage: (row.integer(27) ?? 0) != 0,
            translated: (row.integer(28) ?? 0) != 0,
            screenSharing: (row.integer(29) ?? 0) != 0,
            wasEmergency: (row.integer(30) ?? 0) != 0,
            originatingUI: CallCodes.originatingUI(row.integer(31)),
            originatingUICode: row.integer(31),
            disconnectedCause: row.integer(32),
            filteredOutReason: row.integer(33),
            conversationID: CallCodes.uuidString(row.blob(34)),
            participantGroupID: CallCodes.uuidString(row.blob(35)),
            reminderID: CallCodes.uuidString(row.blob(36))
        )
    }

    /// Every ZHANDLE row by its key.
    static func handles(in database: SQLiteDatabase) throws(CallLogError) -> [Int: Participant] {
        guard !database.columns(of: "ZHANDLE").isEmpty else { return [:] }
        var handles: [Int: Participant] = [:]
        try database.query("SELECT Z_PK, ZVALUE, ZNORMALIZEDVALUE, ZTYPE FROM ZHANDLE") { row in
            guard let key = row.integer(0), let value = row.text(1) ?? row.text(2) else { return }
            handles[key] = Participant(address: value, normalized: row.text(2), kind: HandleKind(code: row.integer(3)) ?? .unknown)
        }
        return handles
    }

    /// Each call's remote participants, through the many-to-many table.
    ///
    /// Core Data names that table after entity numbers —
    /// Z_2REMOTEPARTICIPANTHANDLES with columns Z_2REMOTEPARTICIPANTCALLS and
    /// Z_4REMOTEPARTICIPANTHANDLES today — and the numbers move when the
    /// model gains an entity, so it is found by its suffixes.
    static func participants(in database: SQLiteDatabase, handles: [Int: Participant]) throws(CallLogError) -> [Int: [Participant]] {
        var table: String?
        try database.query("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'Z\\_%REMOTEPARTICIPANTHANDLES' ESCAPE '\\'") { row in
            table = table ?? row.text(0)
        }
        guard let table else { return [:] }
        let columns = database.columns(of: table)
        guard let callColumn = columns.first(where: { $0.hasSuffix("REMOTEPARTICIPANTCALLS") }),
              let handleColumn = columns.first(where: { $0.hasSuffix("REMOTEPARTICIPANTHANDLES") }) else { return [:] }
        var byCall: [Int: [Participant]] = [:]
        try database.query("SELECT \(callColumn), \(handleColumn) FROM \(table) ORDER BY \(handleColumn)") { row in
            guard let call = row.integer(0), let handle = row.integer(1).flatMap({ handles[$0] }) else { return }
            byCall[call, default: []].append(handle)
        }
        return byCall
    }
}
