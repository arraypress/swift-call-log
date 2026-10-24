//
//  IdentityType.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// What a Call Directory extension said the caller is.
public enum IdentityType: String, Codable, Sendable, CaseIterable {

    case unknown

    case person

    case business
}
