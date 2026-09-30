import XCTest
@testable import Pentaphor
import PentaphorCore

final class LocalizationTests: XCTestCase {
    func testRecapCountsUseSingularAndPlural() {
        let en = AppLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "ko_KR"))
        XCTAssertEqual(en.format("recap.times", 1), "1 time")
        XCTAssertEqual(en.format("recap.times", 2), "2 times")
        XCTAssertEqual(en.format("recap.actions", 1), "1 action")
        XCTAssertEqual(en.format("recap.actions", 0), "0 actions")
    }
    func testDatesUseExplicitLocaleAndStoredTimeZone() {
        let date = ISO8601DateFormatter().date(from: "2026-09-30T23:30:00Z")!
        let zone = TimeZone(identifier: "Asia/Seoul")!
        XCTAssertEqual(LocalizedDisplayFormat.day(date, locale: Locale(identifier: "en_US"), timeZone: zone, includeYear: false), "Oct 1")
        XCTAssertEqual(LocalizedDisplayFormat.day(date, locale: Locale(identifier: "ko_KR"), timeZone: zone, includeYear: false), "10월 1일")
        XCTAssertEqual(LocalizedDisplayFormat.weekday(2, locale: Locale(identifier: "en_US")), "Mon")
    }
    func testEnglishAndKoreanResourcesPreserveUserText() {
        let en = AppLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "ko_KR"))
        let ko = AppLocalization.text(preferredLanguages: ["ko"], locale: Locale(identifier: "en_US"))
        XCTAssertEqual(en.string("DesignSystem.1"), "Settings")
        XCTAssertEqual(ko.string("DesignSystem.1"), "설정")
        XCTAssertEqual(en.format("JournalViews.2", "설정 100% 📚"), "설정 100% 📚's parameters")
    }
}
