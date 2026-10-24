//
//  CallStatus.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// How a call ended up, by Apple's own rule (see ``CallCodes/status(duration:originated:answered:)``).
public enum CallStatus: String, Codable, Sendable, CaseIterable {

    /// Incoming and talked: it has a duration.
    case answered

    /// Incoming, and nobody picked up anywhere.
    case missed

    /// Incoming, picked up on another device (the iPhone, usually), so no duration here.
    case answeredElsewhere

    /// Outgoing and talked: it has a duration.
    case connected

    /// Outgoing, hung up before anyone answered.
    case cancelled
}
