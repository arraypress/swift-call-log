//
//  Participant.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Someone on the other end of a call.
///
/// The store keeps addresses, never names: names come from Contacts, which
/// is the caller's to read (``name`` is left for it to fill).
public struct Participant: Codable, Sendable, Hashable {

    /// The address as stored: `+447700900123`, or an email for FaceTime.
    public var address: String

    /// The store's normalised form of it, when it keeps one.
    public var normalized: String?

    /// What the address is.
    public var kind: HandleKind

    /// A name from Contacts, filled by the caller.
    public var name: String?

    public init(address: String, normalized: String? = nil, kind: HandleKind = .unknown, name: String? = nil) {
        self.address = address
        self.normalized = normalized
        self.kind = kind
        self.name = name
    }
}
