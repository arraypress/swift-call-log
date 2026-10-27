//
//  CallLogStore.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  The calls, from CallHistory.storedata — the Core Data store callhistoryd
//  keeps for Phone, FaceTime and every CallKit app. Read from a private copy
//  (swift-sqlite-reader's snapshot); the live store is never opened.
//

import Foundation
import SQLiteReader

/// A Mac's call history, read-only.
public struct CallLogStore: Sendable {

    /// Where each store is.
    public let locations: CallLocations

    public init(locations: CallLocations = CallLocations()) {
        self.locations = locations
    }

    /// Every call, newest first.
    public func calls() throws(CallLogError) -> [Call] {
        return try CallRows.calls(in: SQLiteReader.snapshot(of: locations.callHistory))
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

    static func calls(in database: SQLiteReader) throws(CallLogError) -> [Call] {
        let present = database.columns(of: "ZCALLRECORD")
        guard !present.isEmpty else { throw .unreadable("CallHistory.storedata", reason: "no ZCALLRECORD table") }
        let handles = try self.handles(in: database)
        let participants = try self.participants(in: database, handles: handles)
        let select = columns.map { present.contains($0) ? $0 : "NULL" }.joined(separator: ", ")
        var calls: [Call] = []
        try database.read("SELECT \(select) FROM ZCALLRECORD ORDER BY ZDATE DESC") { row in
            if let call = call(row, participants: participants, handles: handles) { calls.append(call) }
        }
        return calls
    }

    /// One row, or `nil` for one without an id or date.
    static func call(_ row: SQLiteRow, participants: [Int: [Participant]], handles: [Int: Participant]) -> Call? {
        guard let key = row[0].truncatedInt, let id = row[1].nonEmptyString, let seconds = row[2].double else { return nil }
        let duration = max(0, row[3].double ?? 0)
        let originated = (row[4].truncatedInt ?? 0) != 0
        let provider = row[8].nonEmptyString ?? CallCodes.telephonyProvider
        var media = CallCodes.media(category: row[6].truncatedInt)
        if media == .unknown { media = CallCodes.media(callType: row[7].truncatedInt) }
        let address = row[9].nonEmptyString
        var people = participants[key] ?? []
        if people.isEmpty, let address {
            people = [Participant(address: address, kind: HandleKind(code: row[11].truncatedInt) ?? .unknown, name: row[10].nonEmptyString)]
        }
        return Call(
            id: id,
            date: Date(timeIntervalSinceReferenceDate: seconds),
            duration: duration,
            direction: originated ? .outgoing : .incoming,
            status: CallCodes.status(duration: duration, originated: originated, answered: (row[5].truncatedInt ?? 0) != 0),
            media: media,
            service: CallCodes.service(provider: provider),
            provider: provider,
            address: address ?? people.first?.address,
            participants: people,
            initiator: row[37].truncatedInt.flatMap { handles[$0] },
            read: (row[12].truncatedInt ?? 1) != 0,
            location: row[13].nonEmptyString,
            countryCode: row[14].nonEmptyString?.lowercased(),
            device: row[15].nonEmptyString,
            bytesUsed: row[16].truncatedInt.flatMap { $0 > 0 ? $0 : nil },
            trust: TrustScore(code: row[17].truncatedInt),
            verification: VerificationStatus(code: row[18].truncatedInt),
            junkConfidence: JunkConfidence(code: row[19].truncatedInt),
            junkCategory: row[20].nonEmptyString,
            blockedByExtension: row[21].nonEmptyString,
            blockedByExtensionName: row[22].nonEmptyString,
            identityExtension: row[23].nonEmptyString,
            identityType: IdentityType(code: row[24].truncatedInt),
            callerID: CallerIDAvailability(code: row[25].truncatedInt),
            screened: (row[26].truncatedInt ?? 0) != 0,
            hasMessage: (row[27].truncatedInt ?? 0) != 0,
            translated: (row[28].truncatedInt ?? 0) != 0,
            screenSharing: (row[29].truncatedInt ?? 0) != 0,
            wasEmergency: (row[30].truncatedInt ?? 0) != 0,
            originatingUI: CallCodes.originatingUI(row[31].truncatedInt),
            originatingUICode: row[31].truncatedInt,
            disconnectedCause: row[32].truncatedInt,
            filteredOutReason: row[33].truncatedInt,
            conversationID: CallCodes.uuidString(row[34].data),
            participantGroupID: CallCodes.uuidString(row[35].data),
            reminderID: CallCodes.uuidString(row[36].data)
        )
    }

    /// Every ZHANDLE row by its key.
    static func handles(in database: SQLiteReader) throws(CallLogError) -> [Int: Participant] {
        guard !database.columns(of: "ZHANDLE").isEmpty else { return [:] }
        var handles: [Int: Participant] = [:]
        try database.read("SELECT Z_PK, ZVALUE, ZNORMALIZEDVALUE, ZTYPE FROM ZHANDLE") { row in
            guard let key = row[0].truncatedInt, let value = row[1].nonEmptyString ?? row[2].nonEmptyString else { return }
            handles[key] = Participant(address: value, normalized: row[2].nonEmptyString, kind: HandleKind(code: row[3].truncatedInt) ?? .unknown)
        }
        return handles
    }

    /// Each call's remote participants, through the many-to-many table.
    ///
    /// Core Data names that table after entity numbers —
    /// Z_2REMOTEPARTICIPANTHANDLES with columns Z_2REMOTEPARTICIPANTCALLS and
    /// Z_4REMOTEPARTICIPANTHANDLES today — and the numbers move when the
    /// model gains an entity, so it is found by its suffixes.
    static func participants(in database: SQLiteReader, handles: [Int: Participant]) throws(CallLogError) -> [Int: [Participant]] {
        var table: String?
        try database.read("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'Z\\_%REMOTEPARTICIPANTHANDLES' ESCAPE '\\'") { row in
            table = table ?? row[0].nonEmptyString
        }
        guard let table else { return [:] }
        let columns = database.columns(of: table)
        guard let callColumn = columns.first(where: { $0.hasSuffix("REMOTEPARTICIPANTCALLS") }),
              let handleColumn = columns.first(where: { $0.hasSuffix("REMOTEPARTICIPANTHANDLES") }) else { return [:] }
        var byCall: [Int: [Participant]] = [:]
        try database.read("SELECT \(callColumn), \(handleColumn) FROM \(table) ORDER BY \(handleColumn)") { row in
            guard let call = row[0].truncatedInt, let handle = row[1].truncatedInt.flatMap({ handles[$0] }) else { return }
            byCall[call, default: []].append(handle)
        }
        return byCall
    }
}
