//
//  TranscriptionStatus.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Where a message's transcript stands.
public enum TranscriptionStatus: String, Codable, Sendable, CaseIterable {

    case pending

    case deferred

    case inProgress

    case available

    /// The system decided not to transcribe it.
    case none
}
