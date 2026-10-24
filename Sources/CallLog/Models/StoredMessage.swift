//
//  StoredMessage.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A voicemail, or another message left when a call went unanswered, from
/// the FaceTime message store the Phone and FaceTime apps share.
public struct StoredMessage: Codable, Sendable, Hashable, Identifiable {

    /// The record id (a UUID string) — also the name of its audio file.
    public var id: String

    /// When it was left.
    public var date: Date

    /// Who left it, as an address.
    public var from: String?

    /// A name from Contacts, filled by the caller.
    public var fromName: String?

    /// Its length in seconds.
    public var duration: Double

    /// What it is: `voicemail` for type 0 (the only type seen so far: audio
    /// left on the phone network), otherwise `type-<n>`.
    public var kind: String
    public var typeCode: Int?

    /// The service that delivered it.
    public var service: CallService
    public var provider: String?

    public var mailbox: Mailbox?
    public var read: Bool

    /// When it was deleted; deleted messages keep their row but lose their file.
    public var deleted: Date?

    public var transcriptionStatus: TranscriptionStatus?

    /// The transcript, joined — text a stranger may have spoken.
    public var transcript: String?

    /// The transcript in its pieces, with the recogniser's confidence.
    public var segments: [TranscriptSegment]

    /// The audio file, when it is still on disk.
    public var file: String?

    /// The call it was left on, as a ``Call/id`` — when that call is still
    /// in the history (most are pruned before their messages are).
    public var callID: String?

    /// Whether the system marked it sensitive.
    public var sensitive: Bool

    public init(
        id: String, date: Date, from: String? = nil, fromName: String? = nil, duration: Double = 0,
        kind: String = "voicemail", typeCode: Int? = nil, service: CallService = .phone, provider: String? = nil,
        mailbox: Mailbox? = nil, read: Bool = true, deleted: Date? = nil,
        transcriptionStatus: TranscriptionStatus? = nil, transcript: String? = nil,
        segments: [TranscriptSegment] = [], file: String? = nil, callID: String? = nil, sensitive: Bool = false
    ) {
        self.id = id
        self.date = date
        self.from = from
        self.fromName = fromName
        self.duration = duration
        self.kind = kind
        self.typeCode = typeCode
        self.service = service
        self.provider = provider
        self.mailbox = mailbox
        self.read = read
        self.deleted = deleted
        self.transcriptionStatus = transcriptionStatus
        self.transcript = transcript
        self.segments = segments
        self.file = file
        self.callID = callID
        self.sensitive = sensitive
    }
}

/// One piece of a transcript.
public struct TranscriptSegment: Codable, Sendable, Hashable {

    public var text: String

    /// The recogniser's confidence, as it stored it (not a 0–1 probability).
    public var confidence: Double?

    public init(text: String, confidence: Double? = nil) {
        self.text = text
        self.confidence = confidence
    }
}
