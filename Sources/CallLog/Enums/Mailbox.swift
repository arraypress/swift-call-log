//
//  Mailbox.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

/// Which mailbox a stored message sits in.
public enum Mailbox: String, Codable, Sendable, CaseIterable {

    case inbox

    case junk

    case trash
}
