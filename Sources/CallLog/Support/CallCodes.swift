//
//  CallCodes.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  The stores' numeric codes, and what they mean. MEASURED on macOS 27.0.1,
//  never guessed: the Swift enums' tables were read out of Apple's own
//  CallHistory and FaceTimeMessageStore frameworks (each enum's allCases and
//  rawValue, loaded in-process), the ObjC constants with dlsym, and the
//  status rule by calling +[CHManager CHCallStatusForCallWithDuration:
//  isOriginated:isAnswered:] on every combination. Apple's in-process reader
//  (CHManager.recentCalls) then agreed with this decoding on every call in a real history.
//

import Foundation

/// The code tables.
public enum CallCodes {

    // MARK: Status

    /// A call's status, exactly as Apple computes it.
    ///
    /// The duration decides first: ANY duration is a connected call, even
    /// when the answered flag is 0 (outgoing calls never set it). Only a
    /// zero-length call looks at the flags — and an answered zero-length
    /// incoming call is one picked up on another device.
    public static func status(duration: Double, originated: Bool, answered: Bool) -> CallStatus {
        if duration > 0 { return originated ? .connected : .answered }
        if originated { return .cancelled }
        return answered ? .answeredElsewhere : .missed
    }

    // MARK: Media and service

    /// The media for ZCALL_CATEGORY: 1 audio, 2 video, 4 TTY direct, 8 TTY relay.
    public static func media(category: Int?) -> CallMedia {
        switch category {
        case 1: .audio
        case 2: .video
        case 4: .ttyDirect
        case 8: .ttyRelay
        default: .unknown
        }
    }

    /// The media for ZCALLTYPE, for rows without a category: 1 phone audio,
    /// 8 FaceTime video, 16 FaceTime audio.
    public static func media(callType: Int?) -> CallMedia {
        switch callType {
        case 1, 16: .audio
        case 8: .video
        default: .unknown
        }
    }

    /// Apple's identifiers for its two calling services.
    public static let telephonyProvider = "com.apple.Telephony"
    public static let faceTimeProvider = "com.apple.FaceTime"

    /// The service for a ZSERVICE_PROVIDER value.
    public static func service(provider: String?) -> CallService {
        switch provider?.lowercased() {
        case telephonyProvider.lowercased(), "com.apple.coretelephony": .phone
        case faceTimeProvider.lowercased(), "com.apple.telephonyutilities.callservicesd.facetimeprovider": .facetime
        case nil: .phone
        default: .app
        }
    }

    // MARK: Enum tables (index = Apple's raw value)

    static let handleKinds: [HandleKind] = [.unknown, .generic, .phoneNumber, .email]
    static let trustScores: [TrustScore] = [
        .blocked, .junk, .blockedByThirdParty, .suspectedJunk, .unknown,
        .communicatedWith, .identifiedByThirdParty, .maybe, .contact, .vip,
    ]
    static let verifications: [VerificationStatus] = [.notSet, .passed, .failed, .unknown, .noInfo]
    static let junkConfidences: [JunkConfidence] = [.none, .low, .medium, .high]
    static let callerIDs: [CallerIDAvailability] = [.available, .blocked, .unavailable]
    static let identityTypes: [IdentityType] = [.unknown, .person, .business]
    static let mailboxes: [Mailbox] = [.inbox, .junk, .trash]
    static let transcriptionStatuses: [TranscriptionStatus] = [.pending, .deferred, .inProgress, .available, .none]

    /// The value at `code` in an Apple-ordered table.
    static func lookup<T>(_ table: [T], _ code: Int?) -> T? {
        guard let code, table.indices.contains(code) else { return nil }
        return table[code]
    }

    /// Apple's OriginatingUIType names, by raw value — where a call was
    /// started from. 45 (`answerIncoming`) is every incoming call answered here.
    static let originatingUINames: [String] = [
        "unspecified", "dialer", "emergencyDialerLockscreen", "sideButtonPresses", "volumeLockHold",
        "sideButtonHold", "fallDetection", "ecg", "phoneRecents", "phoneFavorites",
        "crashDetection", "siri", "crashDetectionUserResponsive", "fallDetectionUserResponsive", "faceTimeRecents",
        "faceTimeLink", "contactCard", "messagesContactCard", "messagesAvatarBar", "messagesBubble",
        "faceTimeOngoing", "faceTimeCreateCall", "spotlight", "missedCallNotification", "groupFaceTimeNotification",
        "redial", "dialerCallButtonDoubleTap", "inCallUI", "inCallDFR", "assistiveAccessDialer",
        "assistiveAccessContact", "assistiveAccessRecents", "messagesScreenSharing", "fromStaging", "app",
        "tuTool", "tests", "userActivity", "explicitCallTransfer", "callBackButtonTap",
        "fieldModeSendButtonTap", "dialVoicemail", "voiceDial", "handoff", "nac",
        "answerIncoming", "carPlayAnswerIncoming", "carPlayRecents", "carPlayCallBackButtonTap", "recentsSearchCall",
        "recentsSearchVoicemail", "fallbackToTelephony", "gftasService", "visionPeopleUIAddToCall", "visionPeopleUIFavorite",
        "visionPeopleUISuggestion", "visionPeopleUINewCall", "visionPeopleUIDialer", "screeningCall", "fromExpanseProvider",
        "internalRequestedTransaction", "thirdPartyDialer", "translation", "gameOverlay", "carPlayDashboard",
        "macSharePlayNotification",
    ]

    /// The name for an OriginatingUIType code, if Apple's table has one.
    public static func originatingUI(_ code: Int?) -> String? {
        lookup(originatingUINames, code)
    }

    // MARK: Messages

    /// The kind of a stored message: type 0 is a voicemail (measured: audio
    /// left on the phone network); other types are named by number until
    /// one is seen.
    public static func messageKind(_ code: Int?) -> String {
        guard let code, code != 0 else { return "voicemail" }
        return "type-\(code)"
    }

    // MARK: Blobs

    /// A 16-byte UUID blob as the upper-case string the stores print.
    static func uuidString(_ blob: Data?) -> String? {
        guard let blob, blob.count == 16 else { return nil }
        return blob.withUnsafeBytes { raw in
            NSUUID(uuidBytes: raw.bindMemory(to: UInt8.self).baseAddress).uuidString
        }
    }
}
