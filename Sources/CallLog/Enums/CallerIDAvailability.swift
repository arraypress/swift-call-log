//
//  CallerIDAvailability.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Whether the caller's number came through.
public enum CallerIDAvailability: String, Codable, Sendable, CaseIterable {

    case available

    /// The caller withheld it.
    case blocked

    /// The network did not pass it on.
    case unavailable
}
