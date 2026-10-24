//
//  BlockedKind.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// What a block-list entry blocks.
public enum BlockedKind: String, Codable, Sendable, CaseIterable {

    case phoneNumber

    case email

    /// An entry this library does not recognise; ``BlockedItem/typeCode`` keeps the code.
    case other
}
