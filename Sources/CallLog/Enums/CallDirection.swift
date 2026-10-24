//
//  CallDirection.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Who placed the call.
public enum CallDirection: String, Codable, Sendable, CaseIterable {

    /// They called.
    case incoming

    /// This Mac, or a device sharing its account, called.
    case outgoing
}
