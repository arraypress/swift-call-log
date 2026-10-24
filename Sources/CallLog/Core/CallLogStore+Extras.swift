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

extension CallLogStore {

    /// Every FaceTime link this account made, newest first.
    ///
    /// The private key column is never selected.
    public func links() throws(CallLogError) -> [FaceTimeLink] {
        let snapshot = try DatabaseSnapshot(of: locations.links)
        let database = snapshot.database
        let present = database.columns(of: "ZCONVERSATIONLINK")
        guard !present.isEmpty else { return [] }
        var handles: [Int: (value: String, invitedTo: Int?, originated: Int?)] = [:]
        if !database.columns(of: "ZHANDLE").isEmpty {
            try database.query("SELECT Z_PK, ZVALUE, ZINVITEDCONVERSATIONLINK, ZORIGINATORCONVERSATIONLINK FROM ZHANDLE") { row in
                guard let key = row.integer(0), let value = row.text(1) else { return }
                handles[key] = (value, row.integer(2), row.integer(3))
            }
        }
        let wanted = ["Z_PK", "ZNAME", "ZCREATIONDATE", "ZEXPIRATIONDATE", "ZDELETIONDATE", "ZDELETEREASON",
                      "ZACTIVATED", "ZORIGINATORHANDLE", "ZLIFETIMETYPE"]
        let select = wanted.map { present.contains($0) ? $0 : "NULL" }.joined(separator: ", ")
        var links: [FaceTimeLink] = []
        try database.query("SELECT \(select) FROM ZCONVERSATIONLINK ORDER BY ZCREATIONDATE DESC") { row in
            let key = row.integer(0)
            links.append(FaceTimeLink(
                name: row.text(1),
                created: row.double(2).map { Date(timeIntervalSinceReferenceDate: $0) },
                expires: row.double(3).map { Date(timeIntervalSinceReferenceDate: $0) },
                deleted: row.double(4).map { Date(timeIntervalSinceReferenceDate: $0) },
                deleteReasonCode: row.integer(5),
                activated: (row.integer(6) ?? 0) != 0,
                originator: row.integer(7).flatMap { handles[$0]?.value },
                invited: handles.values.filter { $0.invitedTo == key && key != nil }.map(\.value).sorted(),
                lifetimeCode: row.integer(8)
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
        switch PermissionCheck.access(path) {
        case .readable: break
        case .missing: return [:]
        case .refused: throw .needsFullDiskAccess(path)
        }
        do {
            let data = try Data(contentsOf: locations.blockList)
            return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
        } catch {
            if PermissionCheck.isRefusal(error) { throw .needsFullDiskAccess(path) }
            throw .unreadable(path, reason: error.localizedDescription)
        }
    }
}
