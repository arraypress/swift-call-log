//
//  FaceTimeLink.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A FaceTime link this account created.
///
/// No URL: the store holds a pseudonym and key pair that Apple's own builder
/// turns into the link, and a rebuild checked against that builder did not
/// match — so none is offered rather than a wrong one. The private key is
/// never read.
public struct FaceTimeLink: Codable, Sendable, Hashable {

    /// The name given to it, if any.
    public var name: String?

    public var created: Date?
    public var expires: Date?

    /// When it was deleted, if it was.
    public var deleted: Date?
    public var deleteReasonCode: Int?

    /// Whether anyone has used it.
    public var activated: Bool

    /// The account address that made it.
    public var originator: String?

    /// Who it was sent to.
    public var invited: [String]

    public var lifetimeCode: Int?

    public init(
        name: String? = nil, created: Date? = nil, expires: Date? = nil, deleted: Date? = nil,
        deleteReasonCode: Int? = nil, activated: Bool = false, originator: String? = nil,
        invited: [String] = [], lifetimeCode: Int? = nil
    ) {
        self.name = name
        self.created = created
        self.expires = expires
        self.deleted = deleted
        self.deleteReasonCode = deleteReasonCode
        self.activated = activated
        self.originator = originator
        self.invited = invited
        self.lifetimeCode = lifetimeCode
    }
}
