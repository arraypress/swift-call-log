//
//  BlockedItem.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// One entry on the block list Phone, FaceTime and Messages share (synced
/// through iCloud, so the iPhone's list too).
public struct BlockedItem: Codable, Sendable, Hashable {

    public var kind: BlockedKind

    /// The number (E.164, `+447700900123`) or email.
    public var value: String

    /// The number's country, ISO 3166 lower case.
    public var countryCode: String?

    /// The store's type code: 0 phone, 1 email.
    public var typeCode: Int?

    /// A name from Contacts, filled by the caller.
    public var name: String?

    public init(kind: BlockedKind, value: String, countryCode: String? = nil, typeCode: Int? = nil, name: String? = nil) {
        self.kind = kind
        self.value = value
        self.countryCode = countryCode
        self.typeCode = typeCode
        self.name = name
    }
}
