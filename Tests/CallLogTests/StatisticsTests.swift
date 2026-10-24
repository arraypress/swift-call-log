//
//  StatisticsTests.swift
//  CallLogTests
//
//  Created by David Sherlock on 2026.
//

@testable import CallLog
import Foundation
import Testing

struct StatisticsTests {

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// Ada (two numbers), Ben, a stranger.
    var calls: [Call] {
        [
            call("1", at(1, 9), 600, .incoming, .answered, with: "+447700900001"),
            call("2", at(2, 9), 0, .incoming, .missed, with: "+447700900002"),
            call("3", at(2, 10), 120, .outgoing, .connected, with: "+447700900002", service: .phone),
            call("4", at(3, 18), 60, .outgoing, .connected, with: "+447700900011", media: .video),
            call("5", at(5, 18), 0, .incoming, .missed, with: "+447700900009"),
            call("6", at(5, 19), 0, .incoming, .missed, with: "+447700900009"),
            call("7", at(6, 18), 0, .outgoing, .cancelled, with: "+447700900001"),
        ]
    }

    /// Ada's second number folds into her name.
    let ada: PersonKeying = { participant in
        switch participant.address {
        case "+447700900001", "+447700900011": ("Ada", "Ada")
        case "+447700900002": ("Ben", "Ben")
        default: CallStatistics.addressKeying(participant)
        }
    }

    @Test func durationSpread() {
        let summary = CallStatistics.durations([0, 10, 20, 30, 40, 0])
        #expect(summary.calls == 4 && summary.total == 100 && summary.average == 25)
        #expect(summary.median == 25 && summary.longest == 40 && summary.shortest == 10)
        #expect(abs(summary.p90 - 37) < 1e-9)
        #expect(CallStatistics.durations([]) == DurationSummary())
    }

    @Test func overviewCountsEverything() {
        let overview = CallStatistics.overview(calls, keying: ada, calendar: calendar)
        #expect(overview.calls == 7 && overview.people == 3)
        #expect(overview.incoming == 4 && overview.outgoing == 3)
        #expect(overview.answered == 1 && overview.missed == 3 && overview.connected == 2 && overview.cancelled == 1)
        #expect(overview.answerRate == 0.25 && overview.missedRate == 0.75)
        #expect(overview.connectRate == 2.0 / 3.0)
        #expect(overview.talk.total == 780 && overview.talk.calls == 3 && overview.longestCallID == "1")
        #expect(overview.video == 1 && overview.phone == 1 && overview.facetime == 6)
        // Days 1, 2, 3, 5, 6: runs of three and two, one empty day between.
        #expect(overview.activeDays == 5 && overview.longestStreakDays == 3 && overview.longestGapDays == 1)
        #expect(overview.busiestHour == 18)
        // Ben's miss was returned after an hour; the stranger's two were not.
        #expect(overview.missedNotReturned == 2 && overview.medianCallbackSeconds == 3_600)
    }

    @Test func peopleFoldNumbersByKeying() {
        let people = CallStatistics.people(calls, keying: ada, now: at(10, 12), calendar: calendar)
        #expect(people.map(\.key) == ["Ada", "Ben", "447700900009"])
        let first = people[0]
        #expect(first.calls == 3 && first.addresses == ["+447700900001", "+447700900011"])
        #expect(first.outgoing == 2 && first.video == 1 && first.talk.total == 660 && first.daysSinceLast == 4)
        #expect(abs(first.outgoingShare - 2.0 / 3.0) < 1e-9)
        #expect(people[2].missedNotReturned == 2 && people[2].name == nil)
        #expect(people[1].missedNotReturned == 0 && people[1].services == [.facetime, .phone])
    }

    @Test func unreturnedRunsAndCallbacks() {
        let list = CallStatistics.unreturned(calls, keying: ada)
        #expect(list.count == 1)
        #expect(list[0].key == "447700900009" && list[0].missedCalls == 2 && list[0].callID == "6")
        // Getting through again (they called, you answered) closes the run without a call-back.
        let more = calls + [call("8", at(7, 9), 30, .incoming, .answered, with: "+447700900009")]
        #expect(CallStatistics.unreturned(more, keying: ada).isEmpty)
    }

    /// The delay runs from the FIRST missed call of a run: they waited from then.
    @Test func callbackDelayFromTheFirstMiss() {
        let run = [
            call("a", at(1, 9), 0, .incoming, .missed, with: "+447700900002"),
            call("b", at(1, 10), 0, .incoming, .missed, with: "+447700900002"),
            call("c", at(1, 12), 60, .outgoing, .connected, with: "+447700900002"),
        ]
        #expect(CallStatistics.overview(run, calendar: calendar).medianCallbackSeconds == 10_800.0)
        #expect(CallStatistics.unreturned(run).isEmpty)
    }

    /// A blocked spammer is never owed a call back.
    @Test func junkIsNeverUnreturned() {
        var spam = call("9", at(8, 11), 0, .incoming, .missed, with: "021234567", service: .phone)
        spam.trust = .blocked
        #expect(CallStatistics.isJunk(spam))
        #expect(CallStatistics.unreturned(calls + [spam], keying: ada).map(\.key) == ["447700900009"])
        #expect(CallStatistics.overview(calls + [spam], keying: ada, calendar: calendar).missedNotReturned == 2)
        #expect(CallStatistics.overview(calls + [spam], keying: ada, calendar: calendar).junk == 1)
    }

    @Test func bucketsAreCompleteAndOrdered() {
        let hours = CallStatistics.buckets(calls, by: .hour, calendar: calendar)
        #expect(hours.count == 24 && hours[18].key == "18" && hours[18].calls == 3)
        let weekdays = CallStatistics.buckets(calls, by: .weekday, calendar: calendar)
        #expect(weekdays.map(\.key) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        // 2026-10-01 is a Thursday.
        #expect(weekdays[3].calls == 1 && weekdays[3].talkSeconds == 600)
        let days = CallStatistics.buckets(calls, by: .day, calendar: calendar)
        #expect(days.map(\.key) == ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-05", "2026-10-06"])
        let statuses = CallStatistics.buckets(calls, by: .status, calendar: calendar)
        #expect(statuses.first?.key == "missed" && statuses.first?.calls == 3)
        #expect(CallStatistics.buckets(calls, by: .week, calendar: calendar).map(\.key) == ["2026-W40", "2026-W41"])
        #expect(CallStatistics.buckets(calls, by: .month, calendar: calendar).first?.averageSeconds == 260)
    }

    @Test func addressKeys() {
        #expect(CallStatistics.addressKey("+44 7700 900001") == "447700900001")
        #expect(CallStatistics.addressKey("Ada@Example.com") == "ada@example.com")
    }
}
