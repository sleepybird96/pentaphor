import Foundation

enum LocalizedDisplayFormat {
    static func day(_ date: Date, locale: Locale, timeZone: TimeZone, includeYear: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(includeYear ? "yMMMd" : "MMMd")
        return formatter.string(from: date)
    }
    static func weekday(_ weekday: Int, locale: Locale, full: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return (full ? formatter.weekdaySymbols : formatter.shortWeekdaySymbols)[max(0, min(6, weekday - 1))]
    }
}
