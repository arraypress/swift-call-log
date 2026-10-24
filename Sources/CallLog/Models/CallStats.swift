//
//  CallStats.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  The shapes CallStatistics fills. Durations are seconds; talk-time
//  figures count only calls with a duration (answered or connected).
//

import Foundation

/// Spread of call lengths.
public struct DurationSummary: Codable, Sendable, Hashable {
    /// Calls that had a duration.
    public var calls: Int
    public var total: Double
    public var average: Double
    public var median: Double
    /// Nine in ten calls were this long or shorter.
    public var p90: Double
    public var longest: Double
    public var shortest: Double

    public init(calls: Int = 0, total: Double = 0, average: Double = 0, median: Double = 0, p90: Double = 0, longest: Double = 0, shortest: Double = 0) {
        self.calls = calls
        self.total = total
        self.average = average
        self.median = median
        self.p90 = p90
        self.longest = longest
        self.shortest = shortest
    }
}

/// The whole picture for a set of calls.
public struct CallOverview: Codable, Sendable, Hashable {
    public var first: Date?
    public var last: Date?
    public var calls: Int
    public var people: Int

    public var incoming: Int
    public var outgoing: Int
    public var answered: Int
    public var missed: Int
    public var answeredElsewhere: Int
    public var connected: Int
    public var cancelled: Int

    /// Incoming calls picked up anywhere (here or another device), as a share of incoming.
    public var answerRate: Double?
    /// Outgoing calls that connected, as a share of outgoing.
    public var connectRate: Double?
    /// Incoming calls nobody picked up, as a share of incoming.
    public var missedRate: Double?
    /// Outgoing calls as a share of all calls: who starts the conversations.
    public var outgoingShare: Double?

    public var talk: DurationSummary
    public var longestCallID: String?

    public var audio: Int
    public var video: Int
    public var phone: Int
    public var facetime: Int
    public var apps: Int
    public var groupCalls: Int

    /// FaceTime's data use, in bytes.
    public var bytesUsed: Int

    /// Calls from numbers that are not contacts and never talked with before
    /// (trust `unknown`), junk or suspected junk, withheld numbers, and
    /// calls answered by call screening.
    public var unknownCallers: Int
    public var junk: Int
    public var withheld: Int
    public var screened: Int
    public var voicemailsLeft: Int

    /// Days with at least one call, the longest run of such days, and the
    /// longest stretch without a call between two that had one.
    public var activeDays: Int
    public var longestStreakDays: Int
    public var longestGapDays: Int

    /// The busiest hour of the day (0–23) and weekday (1 Sunday … 7 Saturday), by calls.
    public var busiestHour: Int?
    public var busiestWeekday: Int?

    /// Calls per active day, on average.
    public var callsPerActiveDay: Double?

    /// Missed calls never followed by a call back to that person.
    public var missedNotReturned: Int
    /// Median time from a missed call to calling them back.
    public var medianCallbackSeconds: Double?
}

/// One person's calls.
public struct PersonStats: Codable, Sendable, Hashable {
    /// What the calls were grouped by: a contact name when the caller knew
    /// one, otherwise the address.
    public var key: String
    public var name: String?
    /// Every address seen for them.
    public var addresses: [String]

    public var calls: Int
    public var incoming: Int
    public var outgoing: Int
    public var answered: Int
    public var missed: Int
    public var cancelled: Int
    public var video: Int

    public var talk: DurationSummary
    /// Outgoing calls as a share of theirs: 1 means you always call them.
    public var outgoingShare: Double
    public var first: Date
    public var last: Date
    public var daysSinceLast: Int
    /// Missed calls from them never followed by a call back.
    public var missedNotReturned: Int
    public var services: [CallService]

    public init(
        key: String, name: String?, addresses: [String], calls: Int, incoming: Int, outgoing: Int, answered: Int,
        missed: Int, cancelled: Int, video: Int, talk: DurationSummary, outgoingShare: Double, first: Date, last: Date,
        daysSinceLast: Int, missedNotReturned: Int, services: [CallService]
    ) {
        self.key = key
        self.name = name
        self.addresses = addresses
        self.calls = calls
        self.incoming = incoming
        self.outgoing = outgoing
        self.answered = answered
        self.missed = missed
        self.cancelled = cancelled
        self.video = video
        self.talk = talk
        self.outgoingShare = outgoingShare
        self.first = first
        self.last = last
        self.daysSinceLast = daysSinceLast
        self.missedNotReturned = missedNotReturned
        self.services = services
    }
}

/// Calls in one bucket: an hour, a weekday, a day, a service…
public struct BucketStats: Codable, Sendable, Hashable {
    public var key: String
    public var calls: Int
    public var incoming: Int
    public var outgoing: Int
    public var missed: Int
    public var talkSeconds: Double
    public var averageSeconds: Double

    public init(key: String, calls: Int, incoming: Int, outgoing: Int, missed: Int, talkSeconds: Double, averageSeconds: Double) {
        self.key = key
        self.calls = calls
        self.incoming = incoming
        self.outgoing = outgoing
        self.missed = missed
        self.talkSeconds = talkSeconds
        self.averageSeconds = averageSeconds
    }
}

/// What to bucket calls by.
public enum StatsGrouping: String, Codable, Sendable, CaseIterable {
    case hour, weekday, day, week, month, year
    case service, media, status, direction, country, device, trust, origin
}

/// A missed call nobody returned.
public struct UnreturnedCall: Codable, Sendable, Hashable {
    public var key: String
    public var name: String?
    public var address: String?
    /// The most recent missed call from them, and how many are unreturned.
    public var lastMissed: Date
    public var missedCalls: Int
    public var callID: String

    public init(key: String, name: String?, address: String?, lastMissed: Date, missedCalls: Int, callID: String) {
        self.key = key
        self.name = name
        self.address = address
        self.lastMissed = lastMissed
        self.missedCalls = missedCalls
        self.callID = callID
    }
}
