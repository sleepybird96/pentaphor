import Foundation
import Testing
@testable import PentaphorCore

@Suite struct LocalizationTests {
    @Test func resolvesLanguageSeparatelyFromRegion() {
        let en = CoreLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "ko_KR"))
        let ko = CoreLocalization.text(preferredLanguages: ["fr", "ko"], locale: Locale(identifier: "en_US"))
        #expect(en.string("stat.stamina") == "Stamina")
        #expect(ko.string("stat.stamina") == "체력")
        #expect(CoreLocalization.text(preferredLanguages: ["fr"], locale: .current).string("stat.courage") == "Courage")
    }
    @Test func reminderPluralCounts() {
        let en = CoreLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "en_US"))
        #expect(en.format("reminder.week", 1) == "1 more time to reach this week's goal.")
        for count in [0, 2, 99] {
            #expect(en.format("reminder.week", count) == "\(count) more times to reach this week's goal.")
        }
    }
}
