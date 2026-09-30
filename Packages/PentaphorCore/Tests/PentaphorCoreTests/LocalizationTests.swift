import Foundation
import Testing
@testable import PentaphorCore

@Suite struct LocalizationTests {
    @Test func localizedPlanningPreservesDataAndSchedule() throws {
        var engine = QuestEngine(state: AppState(timeZoneID: "Asia/Seoul"))
        let now = ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z")!
        let quest = try engine.create(name: "독서 📚 100%", artID: "reading", cadence: .week, target: 2, rewards: StatPoints(knowledge: 2), at: now)
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [2,3], hour: 20, minute: 0))
        _ = try engine.complete(questID: quest.id, at: now)
        let original = engine.state
        let saved = try JSONEncoder().encode(original)
        let backup = try BackupCodec.make(state: original, at: now)
        let en = CoreLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "en_US"))
        let ko = CoreLocalization.text(preferredLanguages: ["ko"], locale: Locale(identifier: "ko_KR"))
        let english = QuestReminderPlanner.plan(engine: engine, now: now, localeText: en)
        let korean = QuestReminderPlanner.plan(engine: engine, now: now, localeText: ko)
        #expect(!english.isEmpty)
        #expect(english.map(\.id) == korean.map(\.id))
        #expect(english.map(\.fireDate) == korean.map(\.fireDate))
        #expect(english.allSatisfy { $0.title == quest.name })
        #expect(english[0].body != korean[0].body)
        let restored = try JSONDecoder().decode(AppState.self, from: saved)
        #expect(restored == original)
        #expect(try BackupCodec.read(backup).state == original)
        #expect(QuestEngine(state: restored).totals == engine.totals)
        let calculator = PeriodCalculator(timeZoneID: restored.timeZoneID)
        #expect(!calculator.canRecordPreviousWeek(at: now))
        #expect(calculator.canRecordPreviousWeek(at: now.addingTimeInterval(-1)))
        #expect(engine.state == original)
    }
    @Test func resolvesLanguageSeparatelyFromRegion() {
        let en = CoreLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "ko_KR"))
        let ko = CoreLocalization.text(preferredLanguages: ["fr", "ko"], locale: Locale(identifier: "en_US"))
        #expect(en.string("stat.stamina") == "Stamina")
        #expect(ko.string("stat.stamina") == "체력")
        #expect(CoreLocalization.text(preferredLanguages: ["fr"], locale: .current).string("stat.courage") == "Courage")
    }
    @Test func englishPluralRulesDoNotFollowKoreanRegionLanguage() {
        let en = CoreLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "ko_KR"))
        #expect(en.format("reminder.week", 1) == "1 more time to reach this week's goal.")
        for count in [0, 2, 99] {
            #expect(en.format("reminder.week", count) == "\(count) more times to reach this week's goal.")
        }
    }
    @Test func reminderPluralCounts() {
        let en = CoreLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "en_US"))
        #expect(en.format("reminder.week", 1) == "1 more time to reach this week's goal.")
        for count in [0, 2, 99] {
            #expect(en.format("reminder.week", count) == "\(count) more times to reach this week's goal.")
        }
    }
}
