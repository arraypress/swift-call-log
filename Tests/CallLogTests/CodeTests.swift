//
//  CodeTests.swift
//  CallLogTests
//
//  Created by David Sherlock on 2026.
//
//  The code tables against what Apple's frameworks returned when asked
//  (macOS 27.0.1): every expectation here was read out of CallHistory and
//  FaceTimeMessageStore, not written from memory.
//

@testable import CallLog
import Foundation
import Testing

struct CodeTests {

    /// +[CHManager CHCallStatusForCallWithDuration:isOriginated:isAnswered:],
    /// every combination, as it answered: 1 connected incoming, 2 connected
    /// outgoing, 4 answered elsewhere, 8 missed, 16 cancelled.
    @Test(arguments: [
        (0.0, false, false, CallStatus.missed),
        (0.0, false, true, .answeredElsewhere),
        (0.0, true, false, .cancelled),
        (0.0, true, true, .cancelled),
        (0.5, false, false, .answered),
        (0.5, false, true, .answered),
        (30.0, true, false, .connected),
        (30.0, true, true, .connected),
    ])
    func statusIsApplesRule(duration: Double, originated: Bool, answered: Bool, expected: CallStatus) {
        #expect(CallCodes.status(duration: duration, originated: originated, answered: answered) == expected)
    }

    @Test func categoriesAreMedia() {
        #expect(CallCodes.media(category: 1) == .audio)
        #expect(CallCodes.media(category: 2) == .video)
        #expect(CallCodes.media(category: 4) == .ttyDirect)
        #expect(CallCodes.media(category: 8) == .ttyRelay)
        #expect(CallCodes.media(category: 3) == .unknown)
        #expect(CallCodes.media(callType: 8) == .video)
        #expect(CallCodes.media(callType: 16) == .audio)
    }

    @Test func providersAreServices() {
        #expect(CallCodes.service(provider: "com.apple.Telephony") == .phone)
        #expect(CallCodes.service(provider: "com.apple.FaceTime") == .facetime)
        #expect(CallCodes.service(provider: "com.apple.telephonyutilities.callservicesd.FaceTimeProvider") == .facetime)
        #expect(CallCodes.service(provider: "net.whatsapp.WhatsApp") == .app)
    }

    @Test func tablesAreInApplesOrder() {
        #expect(TrustScore(code: 0) == .blocked)
        #expect(TrustScore(code: 4) == .unknown)
        #expect(TrustScore(code: 8) == .contact)
        #expect(TrustScore(code: 9) == .vip)
        #expect(TrustScore(code: 10) == nil)
        #expect(VerificationStatus(code: 4) == .noInfo)
        #expect(CallerIDAvailability(code: 1) == .blocked)
        #expect(HandleKind(code: 3) == .email)
        #expect(Mailbox(code: 2) == .trash)
        #expect(TranscriptionStatus(code: 3) == .available)
        #expect(TranscriptionStatus(code: 5) == nil)
        #expect(CallCodes.originatingUI(45) == "answerIncoming")
        #expect(CallCodes.originatingUI(14) == "faceTimeRecents")
        #expect(CallCodes.originatingUI(65) == "macSharePlayNotification")
        #expect(CallCodes.originatingUI(66) == nil)
        #expect(CallCodes.originatingUINames.count == 66)
    }

    @Test func messageKinds() {
        #expect(CallCodes.messageKind(0) == "voicemail")
        #expect(CallCodes.messageKind(nil) == "voicemail")
        #expect(CallCodes.messageKind(2) == "type-2")
    }

    @Test func uuidBlobs() {
        let uuid = UUID()
        let blob = withUnsafeBytes(of: uuid.uuid) { Data($0) }
        #expect(CallCodes.uuidString(blob) == uuid.uuidString)
        #expect(CallCodes.uuidString(Data([1, 2, 3])) == nil)
    }

    @Test func transcriptsRoundTripAsTUCaption() throws {
        let segments = [TranscriptSegment(text: "Hello, this is a test.", confidence: 18.5), TranscriptSegment(text: "Call me back.", confidence: 9)]
        let archive = TranscriptDecoding.archive(segments)
        // The archive names Apple's class, as the real ones do.
        let plist = try PropertyListSerialization.propertyList(from: archive, format: nil) as? [String: Any]
        let names = (plist?["$objects"] as? [Any])?.compactMap { ($0 as? [String: Any])?["$classname"] as? String }
        #expect(names?.contains("TUCaption") == true)
        #expect(TranscriptDecoding.segments(archive) == segments)
        #expect(TranscriptDecoding.text(segments) == "Hello, this is a test. Call me back.")
        #expect(TranscriptDecoding.segments(Data("not an archive".utf8)).isEmpty)
        #expect(TranscriptDecoding.text([]) == nil)
    }

    @Test func blockListEntries() {
        let preferences: [String: Any] = ["__kCMFBlockListStoreTopLevelKey": [
            "__kCMFBlockListStoreRevisionKey": 46,
            "__kCMFBlockListStoreArrayKey": [
                ["__kCMFItemTypeKey": 0, "__kCMFItemVersionKey": 1,
                 "__kCMFItemPhoneNumberUnformattedKey": "+447700900123", "__kCMFItemPhoneNumberCountryCodeKey": "gb"],
                ["__kCMFItemTypeKey": 1, "__kCMFItemVersionKey": 1, "__kCMFItemEmailUnformattedKey": "spam@example.com"],
                ["__kCMFItemTypeKey": 2, "__kCMFItemVersionKey": 1, "__kCMFItemBusinessIDKey": "biz-1"],
                ["__kCMFItemTypeKey": 0],
            ] as [[String: Any]],
        ] as [String: Any]]
        let items = BlockListParsing.items(preferences)
        #expect(items == [
            BlockedItem(kind: .phoneNumber, value: "+447700900123", countryCode: "gb", typeCode: 0),
            BlockedItem(kind: .email, value: "spam@example.com", typeCode: 1),
            BlockedItem(kind: .other, value: "biz-1", typeCode: 2),
        ])
        #expect(BlockListParsing.revision(preferences) == 46)
        #expect(BlockListParsing.items([:]).isEmpty)
    }
}
