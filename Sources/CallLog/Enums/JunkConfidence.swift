//
//  JunkConfidence.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// How sure the system is that a call was junk.
public enum JunkConfidence: String, Codable, Sendable, CaseIterable {

    case none

    case low

    case medium

    case high
}
