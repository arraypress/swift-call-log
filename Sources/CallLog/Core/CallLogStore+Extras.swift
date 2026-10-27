//
//  CallLogStore+Extras.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  FaceTime links (FaceTime.sqlite3) and the block list (the
//  CommunicationsFilter agent's preferences file).
//

import Foundation
import SQLiteReader

extension CallLogStore {

    /// Every FaceTime link this account made, newest first.
    ///
    /// The private key column is never selected.
    public func links() throws(CallLogError) -> [FaceTimeLink] {
        let database = try SQLiteReader.snapshot(of: locations.links)
        let present = database.columns(of: "ZCONVERSATIONLINK")
        guard !present.isEmpty else { return [] }
        var handles: [Int: (value: String, invitedTo: Int?, originated: Int?)] = [:]
        if !database.columns(of: "ZHANDLE").isEmpty {
            try database.read("SELECT Z_PK, ZVALUE, ZINVITEDCONVERSATIONLINK, ZORIGINATORCONVERSATIONLINK FROM ZHANDLE") { row in
                guard let key = row[0].truncatedInt, let value = row[1].nonEmptyString else { return }
                handles[key] = (value, row[2].truncatedInt, row[3].truncatedInt)
            }
        }
        let wanted = ["Z_PK", "ZNAME", "ZCREATIONDATE", "ZEXPIRATIONDATE", "ZDELETIONDATE", "ZDELETEREASON",
                      "ZACTIVATED", "ZORIGINATORHANDLE", "ZLIFETIMETYPE"]
        let select = wanted.map { present.contains($0) ? $0 : "NULL" }.joined(separator: ", ")
        var links: [FaceTimeLink] = []
        try database.read("SELECT \(select) FROM ZCONVERSATIONLINK ORDER BY ZCREATIONDATE DESC") { row in
            let key = row[0].truncatedInt
            links.append(FaceTimeLink(
                name: row[1].nonEmptyString,
                created: row[2].double.map { Date(timeIntervalSinceReferenceDate: $0) },
                expires: row[3].double.map { Date(timeIntervalSinceReferenceDate: $0) },
                deleted: row[4].double.map { Date(timeIntervalSinceReferenceDate: $0) },
                deleteReasonCode: row[5].truncatedInt,
                activated: (row[6].truncatedInt ?? 0) != 0,
                originator: row[7].truncatedInt.flatMap { handles[$0]?.value },
                invited: handles.values.filter { $0.invitedTo == key && key != nil }.map(\.value).sorted(),
                lifetimeCode: row[8].truncatedInt
            ))
        }
        return links
    }

    /// Every entry on the block list, in its stored order.
    public func blocked() throws(CallLogError) -> [BlockedItem] {
        BlockListParsing.items(try blockListPreferences())
    }

    /// The block list's revision — it rises with every change, from any device.
    public func blockListRevision() throws(CallLogError) -> Int? {
        BlockListParsing.revision(try blockListPreferences())
    }

    /// The agent's preferences file, parsed.
    func blockListPreferences() throws(CallLogError) -> [String: Any] {
        let path = locations.blockList.path
        switch FileChecks.access(path) {
        case .readable: break
        case .missing: return [:]
        case .refused: throw .needsFullDiskAccess(path)
        }
        do {
            let data = try Data(contentsOf: locations.blockList)
            return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
        } catch {
            if FileChecks.isRefusal(error) { throw .needsFullDiskAccess(path) }
            throw .unreadable(path, reason: error.localizedDescription)
        }
    }
}
