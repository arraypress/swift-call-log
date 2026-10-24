//
//  TranscriptDecoding.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  A message's transcript is a keyed archive: an NSArray of TelephonyUtilities'
//  TUCaption, each with `text`, `confidence`, `location`, `length` and
//  `utteranceDuration` (MEASURED: the same shape in ZSTOREDMESSAGE.ZTRANSCRIPT
//  and in the `<id>.plist` beside the audio). TUCaption is private, so a
//  stand-in class takes its name for the unarchive — secure coding stays on,
//  and no Apple framework is linked.
//

import Foundation

/// Reading transcripts.
public enum TranscriptDecoding {

    /// The segments in a TUCaption archive; empty when it is not one.
    public static func segments(_ archive: Data) -> [TranscriptSegment] {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: archive) else { return [] }
        unarchiver.requiresSecureCoding = true
        unarchiver.setClass(CaptionArchive.self, forClassName: CaptionArchive.archivedName)
        defer { unarchiver.finishDecoding() }
        let root = unarchiver.decodeObject(of: [NSArray.self, CaptionArchive.self, NSString.self], forKey: NSKeyedArchiveRootObjectKey)
        let captions = (root as? [CaptionArchive]) ?? (root as? CaptionArchive).map { [$0] } ?? []
        return captions.compactMap { caption in
            let text = caption.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : TranscriptSegment(text: text, confidence: caption.confidence)
        }
    }

    /// The segments joined into one text, `nil` when there are none.
    public static func text(_ segments: [TranscriptSegment]) -> String? {
        let joined = segments.map(\.text).joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    /// An archive of `segments`, as TelephonyUtilities writes one — for
    /// fixtures and tests.
    public static func archive(_ segments: [TranscriptSegment]) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.setClassName(CaptionArchive.archivedName, for: CaptionArchive.self)
        archiver.encode(segments.map { CaptionArchive(text: $0.text, confidence: $0.confidence) } as NSArray, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        return archiver.encodedData
    }
}

/// The stand-in for TUCaption: just the fields a transcript needs.
final class CaptionArchive: NSObject, NSSecureCoding {

    /// The class name in the archive.
    static let archivedName = "TUCaption"

    static var supportsSecureCoding: Bool { true }

    let text: String
    let confidence: Double?

    init(text: String, confidence: Double?) {
        self.text = text
        self.confidence = confidence
    }

    init?(coder: NSCoder) {
        text = (coder.decodeObject(of: NSString.self, forKey: "text") as String?) ?? ""
        confidence = coder.containsValue(forKey: "confidence") ? coder.decodeDouble(forKey: "confidence") : nil
    }

    func encode(with coder: NSCoder) {
        coder.encode(text as NSString, forKey: "text")
        if let confidence { coder.encode(confidence, forKey: "confidence") }
        coder.encode(0, forKey: "location")
        coder.encode(text.utf16.count, forKey: "length")
    }
}
