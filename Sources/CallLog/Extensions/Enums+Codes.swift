//
//  Enums+Codes.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  Each enum from the store's number for it — Apple's raw value — by way
//  of the tables in CallCodes. `nil` for a code the table does not have.
//

extension HandleKind {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.handleKinds, code) else { return nil }; self = value }
}

extension TrustScore {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.trustScores, code) else { return nil }; self = value }
}

extension VerificationStatus {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.verifications, code) else { return nil }; self = value }
}

extension JunkConfidence {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.junkConfidences, code) else { return nil }; self = value }
}

extension CallerIDAvailability {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.callerIDs, code) else { return nil }; self = value }
}

extension IdentityType {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.identityTypes, code) else { return nil }; self = value }
}

extension Mailbox {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.mailboxes, code) else { return nil }; self = value }
}

extension TranscriptionStatus {
    init?(code: Int?) { guard let value = CallCodes.lookup(CallCodes.transcriptionStatuses, code) else { return nil }; self = value }
}
