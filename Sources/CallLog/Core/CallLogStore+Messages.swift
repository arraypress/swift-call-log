//
//  CallLogStore+Messages.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  Voicemail and other left messages, from facetimemessagestored's store —
//  shared by the Phone and FaceTime apps on macOS 26 and later. A message's
//  audio sits in Assets/<first two characters of its id>/<id>.<type>, with
//  its transcript archived both in the row and in <id>.plist beside it.
//

import Foundation
import SQLiteReader

extension CallLogStore {

    /// Every stored message, newest first — deleted ones included, flagged.
    public func messages() throws(CallLogError) -> [StoredMessage] {
        return try MessageRows.messages(in: SQLiteReader.snapshot(of: locations.messages), assets: locations.messageAssets)
    }

    /// One message by its id.
    public func message(id: String) throws(CallLogError) -> StoredMessage {
        guard let message = try messages().first(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            throw .notFound(id)
        }
        return message
    }
}

/// Turning ZSTOREDMESSAGE rows into messages.
enum MessageRows {

    static let columns = [
        "ZRECORDUUID", "ZDATECREATED", "ZFROM", "ZDURATION", "ZMESSAGETYPE", "ZPROVIDER", "ZMAILBOXTYPE",
        "ZISREAD", "ZDATEDELETED", "ZTRANSCRIPTIONSTATUS", "ZTRANSCRIPT", "ZFILETYPE", "ZCALLUUID", "ZISSENSITIVE",
    ]

    static func messages(in database: SQLiteReader, assets: URL) throws(CallLogError) -> [StoredMessage] {
        let present = database.columns(of: "ZSTOREDMESSAGE")
        guard !present.isEmpty else { throw .unreadable("FaceTimeMessageStore", reason: "no ZSTOREDMESSAGE table") }
        let select = columns.map { present.contains($0) ? $0 : "NULL" }.joined(separator: ", ")
        var messages: [StoredMessage] = []
        try database.read("SELECT \(select) FROM ZSTOREDMESSAGE ORDER BY ZDATECREATED DESC") { row in
            guard let id = CallCodes.uuidString(row[0].data), let seconds = row[1].double else { return }
            let file = audioFile(id: id, type: row[11].nonEmptyString, assets: assets)
            var segments = row[10].data.map(TranscriptDecoding.segments) ?? []
            if segments.isEmpty, let sidecar = try? Data(contentsOf: assetFolder(id, assets).appendingPathComponent("\(id).plist")) {
                segments = TranscriptDecoding.segments(sidecar)
            }
            let provider = row[5].nonEmptyString
            messages.append(StoredMessage(
                id: id,
                date: Date(timeIntervalSinceReferenceDate: seconds),
                from: row[2].nonEmptyString,
                duration: max(0, row[3].double ?? 0),
                kind: CallCodes.messageKind(row[4].truncatedInt),
                typeCode: row[4].truncatedInt,
                service: CallCodes.service(provider: provider),
                provider: provider,
                mailbox: Mailbox(code: row[6].truncatedInt),
                read: (row[7].truncatedInt ?? 0) != 0,
                deleted: row[8].double.map { Date(timeIntervalSinceReferenceDate: $0) },
                transcriptionStatus: TranscriptionStatus(code: row[9].truncatedInt),
                transcript: TranscriptDecoding.text(segments),
                segments: segments,
                file: file?.path,
                callID: CallCodes.uuidString(row[12].data),
                sensitive: (row[13].truncatedInt ?? 0) != 0
            ))
        }
        return messages
    }

    /// Assets/<first two characters of the id>.
    static func assetFolder(_ id: String, _ assets: URL) -> URL {
        assets.appendingPathComponent(String(id.prefix(2)), isDirectory: true)
    }

    /// The message's audio, if it is still on disk: `<id>.<type>` as the row
    /// names the type (`MOV`, measured), else any non-plist file with the id.
    static func audioFile(id: String, type: String?, assets: URL) -> URL? {
        let folder = assetFolder(id, assets)
        if let type, !type.isEmpty {
            let named = folder.appendingPathComponent("\(id).\(type)")
            if FileManager.default.fileExists(atPath: named.path) { return named }
        }
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return entries.sorted()
            .first { $0.hasPrefix(id + ".") && !$0.lowercased().hasSuffix(".plist") }
            .map { folder.appendingPathComponent($0) }
    }
}
