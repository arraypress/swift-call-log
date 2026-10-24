//
//  Call.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One call from the history — every column the store keeps, decoded.
///
/// Codes the library knows become names; the raw number stays beside any
/// code whose meaning is not published (``disconnectedCause``,
/// ``filteredOutReason``, ``originatingUICode``).
public struct Call: Codable, Sendable, Hashable, Identifiable {

    /// The store's unique id for the call (a UUID string).
    public var id: String

    /// When the call started.
    public var date: Date

    /// How long it lasted, in seconds — zero for one nobody answered.
    public var duration: Double

    public var direction: CallDirection
    public var status: CallStatus
    public var media: CallMedia
    public var service: CallService

    /// The service's identifier: `com.apple.Telephony`, `com.apple.FaceTime`,
    /// or a third-party app's bundle identifier.
    public var provider: String

    /// The other side as the store names it (the first participant, for a group).
    public var address: String?

    /// Everyone on the other side.
    public var participants: [Participant]

    /// Who started a group call, when the store records it.
    public var initiator: Participant?

    /// Whether a missed call has been seen.
    public var read: Bool

    /// The caller's place, as the network or the number's prefix gave it.
    public var location: String?

    /// The number's country, ISO 3166 (lower case).
    public var countryCode: String?

    /// The device that took or placed it, when it was another one.
    public var device: String?

    /// FaceTime's data use for the call, in bytes.
    public var bytesUsed: Int?

    public var trust: TrustScore?
    public var verification: VerificationStatus?
    public var junkConfidence: JunkConfidence?

    /// The category a junk-identifying extension gave, if one did.
    public var junkCategory: String?

    /// The Call Directory extension that blocked it, and its name.
    public var blockedByExtension: String?
    public var blockedByExtensionName: String?

    /// The extension that identified the caller.
    public var identityExtension: String?
    public var identityType: IdentityType?
    public var callerID: CallerIDAvailability?

    /// Whether it was answered by the system (call screening) rather than a person.
    public var screened: Bool

    /// Whether a message (voicemail) was left.
    public var hasMessage: Bool

    /// Whether live translation was switched on during it.
    public var translated: Bool

    /// Whether screen sharing (or remote control) happened in it.
    public var screenSharing: Bool

    public var wasEmergency: Bool

    /// Where the call was started from (`faceTimeRecents`, `siri`,
    /// `answerIncoming`…), by Apple's OriginatingUIType; ``originatingUICode``
    /// keeps the number.
    public var originatingUI: String?
    public var originatingUICode: Int?

    /// Raw codes whose meanings Apple does not publish.
    public var disconnectedCause: Int?
    public var filteredOutReason: Int?

    /// FaceTime's conversation and group ids (one group call, many rows).
    public var conversationID: String?
    public var participantGroupID: String?

    /// A "remind me" set from the call, as a Reminders id.
    public var reminderID: String?

    public init(
        id: String, date: Date, duration: Double, direction: CallDirection, status: CallStatus,
        media: CallMedia, service: CallService, provider: String, address: String? = nil,
        participants: [Participant] = [], initiator: Participant? = nil, read: Bool = true,
        location: String? = nil, countryCode: String? = nil, device: String? = nil, bytesUsed: Int? = nil,
        trust: TrustScore? = nil, verification: VerificationStatus? = nil, junkConfidence: JunkConfidence? = nil,
        junkCategory: String? = nil, blockedByExtension: String? = nil, blockedByExtensionName: String? = nil,
        identityExtension: String? = nil, identityType: IdentityType? = nil, callerID: CallerIDAvailability? = nil,
        screened: Bool = false, hasMessage: Bool = false, translated: Bool = false, screenSharing: Bool = false,
        wasEmergency: Bool = false, originatingUI: String? = nil, originatingUICode: Int? = nil,
        disconnectedCause: Int? = nil, filteredOutReason: Int? = nil, conversationID: String? = nil,
        participantGroupID: String? = nil, reminderID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.direction = direction
        self.status = status
        self.media = media
        self.service = service
        self.provider = provider
        self.address = address
        self.participants = participants
        self.initiator = initiator
        self.read = read
        self.location = location
        self.countryCode = countryCode
        self.device = device
        self.bytesUsed = bytesUsed
        self.trust = trust
        self.verification = verification
        self.junkConfidence = junkConfidence
        self.junkCategory = junkCategory
        self.blockedByExtension = blockedByExtension
        self.blockedByExtensionName = blockedByExtensionName
        self.identityExtension = identityExtension
        self.identityType = identityType
        self.callerID = callerID
        self.screened = screened
        self.hasMessage = hasMessage
        self.translated = translated
        self.screenSharing = screenSharing
        self.wasEmergency = wasEmergency
        self.originatingUI = originatingUI
        self.originatingUICode = originatingUICode
        self.disconnectedCause = disconnectedCause
        self.filteredOutReason = filteredOutReason
        self.conversationID = conversationID
        self.participantGroupID = participantGroupID
        self.reminderID = reminderID
    }
}
