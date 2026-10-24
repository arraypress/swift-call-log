//
//  HandleKind.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// What a participant's address is.
public enum HandleKind: String, Codable, Sendable, CaseIterable {

    case unknown

    case generic

    case phoneNumber

    case email
}
