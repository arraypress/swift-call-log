//
//  CallStatistics.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  Everything worth counting in a call history, as pure functions over
//  calls. Who a call was with is decided by a `PersonKeying` the caller
//  passes: the library knows addresses only, so a caller holding Contacts
//  can fold one person's several numbers into one name.
//

import Foundation

/// How a participant maps to a person: a grouping key and, if known, a name.
public typealias PersonKeying = @Sendable (Participant) -> (key: String, name: String?)

/// Counting calls.
public enum CallStatistics {

    // MARK: People

    /// The default keying: the address, digits only for a number (the
    /// store writes E.164, so one number is always the same digits) and
    /// lower-cased for an email. No name.
    public static let addressKeying: PersonKeying = { participant in
        (addressKey(participant.normalized ?? participant.address), participant.name)
    }

    /// An address as a grouping key.
    public static func addressKey(_ address: String) -> String {
        if address.contains("@") { return address.lowercased() }
        let digits = address.filter(\.isNumber)
        return digits.isEmpty ? address.lowercased() : digits
    }

    /// Each call with the people on it, keyed.
    static func keyed(_ calls: [Call], _ keying: PersonKeying) -> [(call: Call, people: [(key: String, name: String?, address: String)])] {
        calls.map { call in
            var seen: Set<String> = []
            let people = call.participants.compactMap { participant -> (String, String?, String)? in
                let (key, name) = keying(participant)
                return seen.insert(key).inserted ? (key, name, participant.address) : nil
            }
            return (call, people)
        }
    }

    // MARK: Durations

    /// The spread of `seconds`, ignoring zeros (calls nobody talked on).
    public static func durations(_ seconds: [Double]) -> DurationSummary {
        let talked = seconds.filter { $0 > 0 }.sorted()
        guard !talked.isEmpty else { return DurationSummary() }
        let total = talked.reduce(0, +)
        return DurationSummary(
            calls: talked.count, total: total, average: total / Double(talked.count),
            median: percentile(talked, 0.5), p90: percentile(talked, 0.9),
            longest: talked.last ?? 0, shortest: talked.first ?? 0
        )
    }

    /// The `fraction` percentile of sorted values, interpolating between neighbours.
    static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? 0 }
        let position = fraction * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }

    // MARK: Overview

    /// The whole picture.
    public static func overview(_ calls: [Call], keying: PersonKeying = addressKeying, calendar: Calendar = .current) -> CallOverview {
        let incoming = calls.filter { $0.direction == .incoming }
        let outgoing = calls.filter { $0.direction == .outgoing }
        let count = { (status: CallStatus) in calls.filter { $0.status == status }.count }
        let answered = count(.answered), missed = count(.missed), elsewhere = count(.answeredElsewhere)
        let connected = count(.connected), cancelled = count(.cancelled)
        let keyed = keyed(calls, keying)
        let days = activeDays(calls, calendar: calendar)
        let returns = callbacks(keyed)
        let hours = Dictionary(grouping: calls) { calendar.component(.hour, from: $0.date) }
        let weekdays = Dictionary(grouping: calls) { calendar.component(.weekday, from: $0.date) }
        return CallOverview(
            first: calls.map(\.date).min(), last: calls.map(\.date).max(),
            calls: calls.count,
            people: Set(keyed.flatMap { $0.people.map(\.key) }).count,
            incoming: incoming.count, outgoing: outgoing.count,
            answered: answered, missed: missed, answeredElsewhere: elsewhere, connected: connected, cancelled: cancelled,
            answerRate: share(answered + elsewhere, of: incoming.count),
            connectRate: share(connected, of: outgoing.count),
            missedRate: share(missed, of: incoming.count),
            outgoingShare: share(outgoing.count, of: calls.count),
            talk: durations(calls.map(\.duration)),
            longestCallID: calls.max { $0.duration < $1.duration }.flatMap { $0.duration > 0 ? $0.id : nil },
            audio: calls.filter { $0.media == .audio }.count,
            video: calls.filter { $0.media == .video }.count,
            phone: calls.filter { $0.service == .phone }.count,
            facetime: calls.filter { $0.service == .facetime }.count,
            apps: calls.filter { $0.service == .app }.count,
            groupCalls: calls.filter { $0.participants.count > 1 }.count,
            bytesUsed: calls.compactMap(\.bytesUsed).reduce(0, +),
            unknownCallers: incoming.filter { $0.trust == .unknown }.count,
            junk: calls.filter(isJunk).count,
            withheld: incoming.filter { $0.callerID == .blocked || $0.callerID == .unavailable }.count,
            screened: calls.filter(\.screened).count,
            voicemailsLeft: calls.filter(\.hasMessage).count,
            activeDays: days.count,
            longestStreakDays: streaks(days, calendar: calendar).longestRun,
            longestGapDays: streaks(days, calendar: calendar).longestGap,
            busiestHour: busiest(hours),
            busiestWeekday: busiest(weekdays),
            callsPerActiveDay: days.isEmpty ? nil : Double(calls.count) / Double(days.count),
            missedNotReturned: returns.unreturned.reduce(0) { $0 + $1.missedCalls },
            medianCallbackSeconds: returns.delays.isEmpty ? nil : percentile(returns.delays.sorted(), 0.5)
        )
    }

    // MARK: Per person

    /// Every person's calls, most calls first (talk time breaks ties).
    public static func people(_ calls: [Call], keying: PersonKeying = addressKeying, now: Date = Date(), calendar: Calendar = .current) -> [PersonStats] {
        let keyed = keyed(calls, keying)
        let unreturned = Dictionary(callbacks(keyed).unreturned.map { ($0.key, $0.missedCalls) }, uniquingKeysWith: +)
        var byPerson: [String: (name: String?, addresses: Set<String>, calls: [Call])] = [:]
        for (call, people) in keyed {
            for person in people {
                var entry = byPerson[person.key] ?? (person.name, [], [])
                entry.name = entry.name ?? person.name
                entry.addresses.insert(person.address)
                entry.calls.append(call)
                byPerson[person.key] = entry
            }
        }
        return byPerson.map { key, entry in
            let calls = entry.calls
            let first = calls.map(\.date).min() ?? now
            let last = calls.map(\.date).max() ?? now
            let outgoing = calls.filter { $0.direction == .outgoing }.count
            return PersonStats(
                key: key, name: entry.name, addresses: entry.addresses.sorted(),
                calls: calls.count,
                incoming: calls.count - outgoing, outgoing: outgoing,
                answered: calls.filter { $0.status == .answered || $0.status == .answeredElsewhere }.count,
                missed: calls.filter { $0.status == .missed }.count,
                cancelled: calls.filter { $0.status == .cancelled }.count,
                video: calls.filter { $0.media == .video }.count,
                talk: durations(calls.map(\.duration)),
                outgoingShare: Double(outgoing) / Double(max(calls.count, 1)),
                first: first, last: last,
                daysSinceLast: max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0),
                missedNotReturned: unreturned[key] ?? 0,
                services: Array(Set(calls.map(\.service))).sorted { $0.rawValue < $1.rawValue }
            )
        }
        .sorted { ($0.calls, $0.talk.total, $0.key) > ($1.calls, $1.talk.total, $1.key) }
    }

    // MARK: Buckets

    /// Calls bucketed. Time buckets come in time order — hours and weekdays
    /// complete, empty ones included, so a chart has every bar; the rest
    /// come busiest first.
    public static func buckets(_ calls: [Call], by grouping: StatsGrouping, calendar: Calendar = .current) -> [BucketStats] {
        let groups = Dictionary(grouping: calls) { bucketKey($0, grouping, calendar) }
        var keys = Array(groups.keys)
        switch grouping {
        case .hour: keys = (0..<24).map { String(format: "%02d", $0) }
        case .weekday: keys = weekdayOrder
        case .day, .week, .month, .year: keys.sort()
        default: keys.sort { (groups[$0]?.count ?? 0, $1) > (groups[$1]?.count ?? 0, $0) }
        }
        return keys.map { key in
            let calls = groups[key] ?? []
            let talk = calls.map(\.duration).filter { $0 > 0 }
            return BucketStats(
                key: key, calls: calls.count,
                incoming: calls.filter { $0.direction == .incoming }.count,
                outgoing: calls.filter { $0.direction == .outgoing }.count,
                missed: calls.filter { $0.status == .missed }.count,
                talkSeconds: talk.reduce(0, +),
                averageSeconds: talk.isEmpty ? 0 : talk.reduce(0, +) / Double(talk.count)
            )
        }
    }

    /// Monday first, as ISO weeks run.
    static let weekdayOrder = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// The bucket a call falls in.
    static func bucketKey(_ call: Call, _ grouping: StatsGrouping, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .weekday], from: call.date)
        switch grouping {
        case .hour: return String(format: "%02d", parts.hour ?? 0)
        case .weekday: return weekdayNames[((parts.weekday ?? 1) - 1) % 7]
        case .day: return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        case .week:
            var iso = Calendar(identifier: .iso8601)
            iso.timeZone = calendar.timeZone
            let week = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: call.date)
            return String(format: "%04d-W%02d", week.yearForWeekOfYear ?? 0, week.weekOfYear ?? 0)
        case .month: return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        case .year: return String(format: "%04d", parts.year ?? 0)
        case .service: return call.service == .app ? call.provider : call.service.rawValue
        case .media: return call.media.rawValue
        case .status: return call.status.rawValue
        case .direction: return call.direction.rawValue
        case .country: return call.countryCode ?? "unknown"
        case .device: return call.device ?? "this device"
        case .trust: return call.trust?.rawValue ?? "unrated"
        case .origin: return call.originatingUI ?? "unknown"
        }
    }

    // MARK: Missed calls and call-backs

    /// Missed calls nobody returned, latest first.
    public static func unreturned(_ calls: [Call], keying: PersonKeying = addressKeying) -> [UnreturnedCall] {
        callbacks(keyed(calls, keying)).unreturned.sorted { $0.lastMissed > $1.lastMissed }
    }

    /// Walks each person's calls in time order. A run of missed calls ends
    /// when you call them (a call-back: its delay from the FIRST missed call
    /// of the run is recorded) or when they get through again (returned, but
    /// not by you — no delay). A run still open at the end is unreturned.
    /// Junk is never owed a call back: a missed call from a blocked or junk
    /// number starts no run (measured: a blocked spammer's call was the top
    /// "unreturned" entry before this).
    static func callbacks(_ keyed: [(call: Call, people: [(key: String, name: String?, address: String)])]) -> (delays: [Double], unreturned: [UnreturnedCall]) {
        var timelines: [String: [(call: Call, name: String?, address: String)]] = [:]
        for (call, people) in keyed {
            for person in people { timelines[person.key, default: []].append((call, person.name, person.address)) }
        }
        var delays: [Double] = []
        var unreturned: [UnreturnedCall] = []
        for (key, timeline) in timelines {
            var run: [Call] = []
            for entry in timeline.sorted(by: { $0.call.date < $1.call.date }) {
                let call = entry.call
                if call.status == .missed {
                    if !isJunk(call) { run.append(call) }
                } else if !run.isEmpty, call.direction == .outgoing {
                    delays.append(call.date.timeIntervalSince(run[0].date))
                    run = []
                } else if call.direction == .incoming {
                    run = []
                }
            }
            if let last = run.last {
                let named = timeline.first { $0.name != nil }
                unreturned.append(UnreturnedCall(key: key, name: named?.name, address: timeline.last?.address,
                                                 lastMissed: last.date, missedCalls: run.count, callID: last.id))
            }
        }
        return (delays, unreturned)
    }

    // MARK: Days

    /// The local days that had a call.
    static func activeDays(_ calls: [Call], calendar: Calendar) -> [Date] {
        Array(Set(calls.map { calendar.startOfDay(for: $0.date) })).sorted()
    }

    /// The longest run of consecutive active days, and the longest gap (in
    /// days without a call) between two active days.
    static func streaks(_ days: [Date], calendar: Calendar) -> (longestRun: Int, longestGap: Int) {
        guard !days.isEmpty else { return (0, 0) }
        var longestRun = 1, run = 1, longestGap = 0
        for (previous, day) in zip(days, days.dropFirst()) {
            let apart = calendar.dateComponents([.day], from: previous, to: day).day ?? 1
            if apart == 1 {
                run += 1
            } else {
                run = 1
                longestGap = max(longestGap, apart - 1)
            }
            longestRun = max(longestRun, run)
        }
        return (longestRun, longestGap)
    }

    // MARK: Helpers

    /// Whether a call was junk: the system blocked it or flagged it, or a
    /// Call Directory extension did.
    public static func isJunk(_ call: Call) -> Bool {
        if let trust = call.trust, [.junk, .suspectedJunk, .blocked, .blockedByThirdParty].contains(trust) { return true }
        return (call.junkConfidence ?? .none) != .none || call.blockedByExtension != nil
    }

    static func share(_ part: Int, of whole: Int) -> Double? {
        whole == 0 ? nil : Double(part) / Double(whole)
    }

    static func busiest(_ groups: [Int: [Call]]) -> Int? {
        groups.max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }?.key
    }
}
