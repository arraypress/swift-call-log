//
//  CallLogError.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading a Mac's call history.
public enum CallLogError: Error, Equatable, Sendable, LocalizedError {

    /// macOS refused to let this process read a store.
    ///
    /// Every store here lives where privacy protection guards it: the refusal
    /// is what a missing Full Disk Access grant looks like. Carries the path.
    case needsFullDiskAccess(String)

    /// The store does not exist — FaceTime or the Phone app has never kept
    /// anything on this Mac. Carries the path.
    case noStore(String)

    /// A store is there and readable but could not be understood.
    case unreadable(String, reason: String)

    /// No call, message or link has this id.
    case notFound(String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .needsFullDiskAccess(let path):
            "Not allowed to read \(path) — macOS keeps call history behind Full Disk Access"
        case .noStore(let path):
            "Nothing at \(path)"
        case .unreadable(let path, let reason):
            "Could not read \(path): \(reason)"
        case .notFound(let id):
            "Nothing has the id \(id)"
        }
    }
}
