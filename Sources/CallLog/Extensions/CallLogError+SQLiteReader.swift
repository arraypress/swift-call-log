//
//  CallLogError+SQLiteReader.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  The stores are read through swift-sqlite-reader; its errors are reported
//  as this library's own, so callers and messages stay the same.
//

import Foundation
import SQLiteReader

extension CallLogError {

    /// This library's error for a reader's.
    init(_ error: SQLiteReaderError) {
        switch error {
        case .notFound(let path): self = .noStore(path)
        case .permissionDenied(let path): self = .needsFullDiskAccess(path)
        case .unreadable(let path, let reason): self = .unreadable(path, reason: reason)
        }
    }
}

extension SQLiteReader {

    /// A private copy of a live store and its log, deleted when the reader
    /// goes: callhistoryd and facetimemessagestored write their stores while
    /// this reads, and one CallHistory file had not been checkpointed for
    /// eleven weeks — every recent call lived only in its log.
    static func snapshot(of store: URL) throws(CallLogError) -> SQLiteReader {
        do { return try SQLiteReader(path: store, opening: .snapshot) } catch { throw CallLogError(error) }
    }

    /// Runs a query, handing each row over, and reports a failure as a ``CallLogError``.
    func read(_ sql: String, row: (SQLiteRow) -> Void) throws(CallLogError) {
        do { try query(sql, row: row) } catch { throw CallLogError(error) }
    }
}
