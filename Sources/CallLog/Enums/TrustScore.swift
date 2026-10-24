//
//  TrustScore.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// How much the system trusts the other side: Apple's CommunicationTrustScore, in its order.
public enum TrustScore: String, Codable, Sendable, CaseIterable {

    case blocked

    case junk

    case blockedByThirdParty

    case suspectedJunk

    case unknown

    /// Not a contact, but someone this account has called or messaged.
    case communicatedWith

    case identifiedByThirdParty

    case maybe

    case contact

    case vip
}
