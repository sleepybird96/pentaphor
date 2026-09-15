import Foundation

public enum Cadence: String, Codable, CaseIterable, Sendable { case once, week, month }

public struct PeriodWindow: Codable, Equatable, Hashable, Sendable {
    public let start: Date
    public let end: Date
    public let cadence: Cadence
    public init(start: Date, end: Date, cadence: Cadence) {
        self.start = start; self.end = end; self.cadence = cadence
    }
}

public struct PeriodCalculator: Sendable {
    private let calendar: Calendar
    public init(timeZoneID: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
    }
    public func period(containing date: Date, cadence: Cadence) -> PeriodWindow {
        // One-time progress has no calendar rollover. These boundaries are internal only.
        if cadence == .once { return PeriodWindow(start: .distantPast, end: .distantFuture, cadence: .once) }
        let interval = calendar.dateInterval(of: cadence == .week ? .weekOfYear : .month, for: date)!
        return PeriodWindow(start: interval.start, end: interval.end, cadence: cadence)
    }
    public func previous(to window: PeriodWindow) -> PeriodWindow {
        if window.cadence == .once { return window }
        return period(containing: calendar.date(byAdding: .day, value: -1, to: window.start)!, cadence: window.cadence)
    }
    public func canRecordPreviousWeek(at date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 2 && calendar.component(.hour, from: date) < 9
    }
}
