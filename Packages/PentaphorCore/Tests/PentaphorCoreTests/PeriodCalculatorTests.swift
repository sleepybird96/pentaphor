import Foundation
import Testing
@testable import PentaphorCore

func instant(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

struct PeriodCalculatorTests {
    let seoul = PeriodCalculator(timeZoneID: "Asia/Seoul")

    @Test func mondayMidnightStartsNewWeekWithoutWaitingForGraceDeadline() {
        let result = seoul.period(containing: instant("2026-09-13T15:00:00Z"), cadence: .week)
        #expect(result.start == instant("2026-09-13T15:00:00Z"))
        #expect(result.end == instant("2026-09-20T15:00:00Z"))
    }
    @Test func sundayNightBelongsToPreviousWeek() {
        let result = seoul.period(containing: instant("2026-09-13T14:59:59Z"), cadence: .week)
        #expect(result.start == instant("2026-09-06T15:00:00Z"))
        #expect(result.end == instant("2026-09-13T15:00:00Z"))
    }
    @Test(arguments: [
        ("2026-09-13T14:59:59Z", false),
        ("2026-09-13T15:00:00Z", true),
        ("2026-09-13T23:59:59Z", true),
        ("2026-09-14T00:00:00Z", false),
        ("2026-09-14T15:00:00Z", false)
    ]) func previousWeekGraceHasExclusiveNineAMBoundary(fixture: (String, Bool)) {
        #expect(seoul.canRecordPreviousWeek(at: instant(fixture.0)) == fixture.1)
    }
    @Test func leapFebruaryUsesCalendarMonth() {
        let result = seoul.period(containing: instant("2028-02-29T10:00:00Z"), cadence: .month)
        #expect(result.start == instant("2028-01-31T15:00:00Z"))
        #expect(result.end == instant("2028-02-29T15:00:00Z"))
        #expect(seoul.previous(to: result).start == instant("2027-12-31T15:00:00Z"))
    }
    @Test func daylightSavingWeekIsNotFixedNumberOfSeconds() {
        let calculator = PeriodCalculator(timeZoneID: "America/New_York")
        let result = calculator.period(containing: instant("2026-03-08T16:00:00Z"), cadence: .week)
        #expect(result.start == instant("2026-03-02T05:00:00Z"))
        #expect(result.end == instant("2026-03-09T04:00:00Z"))
    }
    @Test func yearBoundaryPreviousWeekIsAdjacent() {
        let current = seoul.period(containing: instant("2027-01-03T15:00:00Z"), cadence: .week)
        let previous = seoul.previous(to: current)
        #expect(previous.start == instant("2026-12-27T15:00:00Z"))
        #expect(previous.end == current.start)
    }
}
