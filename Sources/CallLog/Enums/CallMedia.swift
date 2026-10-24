//
//  CallMedia.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// What the call carried, from the store's call category.
public enum CallMedia: String, Codable, Sendable, CaseIterable {

    case audio

    case video

    /// A text telephone, direct.
    case ttyDirect

    /// A text telephone through a relay service.
    case ttyRelay

    /// A category this library does not know.
    case unknown
}
