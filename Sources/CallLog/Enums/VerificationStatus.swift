//
//  VerificationStatus.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Whether the network vouched for the caller's number (STIR/SHAKEN).
public enum VerificationStatus: String, Codable, Sendable, CaseIterable {

    case notSet

    case passed

    case failed

    case unknown

    case noInfo
}
