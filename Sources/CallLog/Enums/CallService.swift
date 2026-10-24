//
//  CallService.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Which service carried the call.
public enum CallService: String, Codable, Sendable, CaseIterable {

    /// The phone network: on a Mac, an iPhone call relayed over Continuity.
    case phone

    /// FaceTime, audio or video.
    case facetime

    /// A third-party calling app that reports to CallKit; ``Call/provider`` holds its bundle identifier.
    case app
}
