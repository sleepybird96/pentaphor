import Foundation
import Testing
@testable import PentaphorCore

struct WeeklyRecapTests {
    private let cutoff = instant("2026-09-14T00:00:00Z")
    private let previous = instant("2026-08-30T15:00:00Z")
    private let recapStart = instant("2026-09-06T15:00:00Z")

    private func fixture() throws -> (QuestEngine, Quest) {
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 2,
                                      rewards: StatPoints(stamina: 2), at: instant("2026-08-01T00:00:00Z"))
        return (engine, quest)
    }

    @Test func cutoffClosesLatestWeekExactlyAtNineInSavedTimezone() {
        #expect(WeeklyRecapBuilder.latestClosedWeek(now: cutoff.addingTimeInterval(-1), timeZoneID: "Asia/Seoul").start == previous)
        let period = WeeklyRecapBuilder.latestClosedWeek(now: cutoff, timeZoneID: "Asia/Seoul")
        #expect(period.start == recapStart)
        #expect(period.end == instant("2026-09-13T15:00:00Z"))
        #expect(period.cadence == .week)
    }

    @Test func cutoffUsesLocalCalendarAcrossDST() {
        let justBefore = instant("2026-03-09T12:59:59Z")
        let atNine = instant("2026-03-09T13:00:00Z")
        #expect(WeeklyRecapBuilder.latestClosedWeek(now: justBefore, timeZoneID: "America/New_York").start == instant("2026-02-23T05:00:00Z"))
        let period = WeeklyRecapBuilder.latestClosedWeek(now: atNine, timeZoneID: "America/New_York")
        #expect(period.start == instant("2026-03-02T05:00:00Z"))
        #expect(period.end == instant("2026-03-09T04:00:00Z"))
    }

    @Test func weeklyGraceStaysInStoredWeekWhileMonthAndOnceUseRecordedWeek() throws {
        var (engine, quest) = try fixture()
        let month = try engine.create(name: "독서", artID: "reading", cadence: .month, target: 1, rewards: StatPoints(knowledge: 2), at: created)
        let once = try engine.create(name: "도전", artID: "running", cadence: .once, target: 1, rewards: StatPoints(courage: 2), at: created)
        try engine.complete(questID: quest.id, at: created)
        let grace = instant("2026-09-13T23:59:59Z")
        try engine.complete(questID: quest.id, at: grace, previousWeek: true)
        try engine.complete(questID: month.id, at: grace)
        try engine.complete(questID: once.id, at: grace)
        let report = try #require(WeeklyRecapBuilder.latest(engine: engine, now: cutoff))
        #expect(report.completionCount == 2)
        #expect(report.questCount == 1)
        #expect(report.weeklyGoalsAchieved == 1)
        #expect(report.gains == StatPoints(stamina: 4))
        #expect(report.activities == [WeeklyRecapActivity(id: quest.id, name: quest.name, artID: quest.artID, cadence: .week, count: 2)])
        let next = try #require(WeeklyRecapBuilder.latest(engine: engine, now: instant("2026-09-21T00:00:00Z")))
        #expect(next.completionCount == 2)
        #expect(next.before == report.after)
        #expect(next.gains == StatPoints(knowledge: 2, courage: 2))
    }

    @Test func editedTargetRecomputesWeeklyGoalAndBonusWhileRewardSnapshotsPreserveGrowth() throws {
        var (engine, quest) = try fixture()
        for day in ["2026-08-31T03:00:00Z", "2026-09-01T03:00:00Z", "2026-09-07T03:00:00Z"] {
            try engine.complete(questID: quest.id, at: instant(day))
        }
        try engine.update(id: quest.id, name: "새 이름", artID: "reading", cadence: .week, target: 9,
                          rewards: StatPoints(knowledge: 1), at: instant("2026-09-08T03:00:00Z"))
        try engine.complete(questID: quest.id, at: instant("2026-09-08T03:00:00Z"))
        try engine.complete(questID: quest.id, at: cutoff)
        let original = engine.state
        let report = try #require(WeeklyRecapBuilder.latest(engine: engine, now: cutoff))
        #expect(report.before == StatPoints(stamina: 4))
        #expect(report.baseGains == StatPoints(stamina: 2, knowledge: 1))
        #expect(report.streakBonus == 0)
        #expect(report.gains == StatPoints(stamina: 2, knowledge: 1))
        #expect(report.after == StatPoints(stamina: 6, knowledge: 1))
        #expect(report.weeklyGoalsAchieved == 0)
        #expect(report.activities.first?.name == "새 이름")
        #expect(engine.state == original)
    }

    @Test func monthlyBonusBelongsOnlyToTargetThNonvoidCompletionWeek() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .month, target: 2,
                                      rewards: StatPoints(knowledge: 1), at: instant("2026-08-01T00:00:00Z"))
        for day in ["2026-08-02T03:00:00Z", "2026-08-03T03:00:00Z", "2026-09-01T03:00:00Z"] {
            try engine.complete(questID: quest.id, at: instant(day))
        }
        let voided = try engine.complete(questID: quest.id, at: instant("2026-09-02T03:00:00Z"))
        try engine.undo(completionID: voided.completion.id)
        try engine.complete(questID: quest.id, at: created)
        try engine.complete(questID: quest.id, at: cutoff)
        // Deliberately reverse storage order; award time follows recordedAt, not array order.
        var state = engine.state
        state.completions.reverse()
        engine = QuestEngine(state: state)
        let earlier = try #require(WeeklyRecapBuilder.latest(engine: engine, now: instant("2026-09-07T00:00:00Z")))
        let report = try #require(WeeklyRecapBuilder.latest(engine: engine, now: cutoff))
        let newer = try #require(WeeklyRecapBuilder.latest(engine: engine, now: instant("2026-09-21T00:00:00Z")))
        #expect(earlier.streakBonus == 0)
        #expect(report.streakBonus == 1)
        #expect(report.before == StatPoints(knowledge: 3))
        #expect(report.after == StatPoints(knowledge: 4, perseverance: 1))
        #expect(newer.streakBonus == 0)
        #expect(newer.before == report.after)
    }

    @Test func archivedAndDeletedQuestHistorySurvivesAndUndoRecomputes() throws {
        var (engine, quest) = try fixture()
        try engine.complete(questID: quest.id, at: created)
        let second = try engine.complete(questID: quest.id, at: created.addingTimeInterval(60))
        try engine.setArchived(id: quest.id, archived: true)
        try engine.delete(id: quest.id, at: cutoff)
        #expect(WeeklyRecapBuilder.latest(engine: engine, now: cutoff)?.completionCount == 2)
        try engine.undo(completionID: second.completion.id)
        let report = try #require(WeeklyRecapBuilder.latest(engine: engine, now: cutoff))
        #expect(report.completionCount == 1)
        #expect(report.weeklyGoalsAchieved == 0)
        #expect(report.gains.stamina == 2)
        #expect(report.activities.first?.id == quest.id)
    }

    @Test func latestOnlyDoesNotQueueOldOrEmptyWeeks() throws {
        var (engine, quest) = try fixture()
        #expect(WeeklyRecapBuilder.pending(engine: engine, now: cutoff) == nil)
        try engine.complete(questID: quest.id, at: instant("2026-08-31T03:00:00Z"))
        #expect(WeeklyRecapBuilder.pending(engine: engine, now: cutoff) == nil)
        let completion = try engine.complete(questID: quest.id, at: created)
        #expect(WeeklyRecapBuilder.pending(engine: engine, now: cutoff)?.period.start == recapStart)
        try engine.undo(completionID: completion.completion.id)
        #expect(WeeklyRecapBuilder.pending(engine: engine, now: cutoff) == nil)
    }

    @Test func acknowledgementIsMonotoneAndChangesNoEarnedState() throws {
        var (engine, quest) = try fixture()
        try engine.complete(questID: quest.id, at: created)
        try engine.complete(questID: quest.id, at: instant("2026-08-31T03:00:00Z"))
        let original = engine.state
        let totals = engine.totals
        try engine.acknowledgeWeeklyRecap(periodStart: recapStart, at: cutoff)
        try engine.acknowledgeWeeklyRecap(periodStart: previous, at: cutoff)
        try engine.acknowledgeWeeklyRecap(periodStart: recapStart, at: cutoff)
        #expect(engine.state.weeklyRecapAcknowledgedThrough == recapStart)
        #expect(engine.state.completions == original.completions)
        #expect(engine.state.quests == original.quests)
        #expect(engine.totals == totals)
        #expect(WeeklyRecapBuilder.pending(engine: engine, now: cutoff) == nil)
        #expect(WeeklyRecapBuilder.latest(engine: engine, now: cutoff) != nil)
        try engine.complete(questID: quest.id, at: cutoff)
        #expect(WeeklyRecapBuilder.pending(engine: engine, now: instant("2026-09-21T00:00:00Z")) != nil)
    }

    @Test func acknowledgementRejectsUnclosedEmptyAndNonWeekStart() throws {
        var (engine, quest) = try fixture()
        try engine.complete(questID: quest.id, at: created)
        let original = engine.state
        #expect(throws: QuestError.invalidState) { try engine.acknowledgeWeeklyRecap(periodStart: recapStart, at: cutoff.addingTimeInterval(-1)) }
        #expect(throws: QuestError.invalidState) { try engine.acknowledgeWeeklyRecap(periodStart: previous, at: cutoff) }
        #expect(throws: QuestError.invalidState) { try engine.acknowledgeWeeklyRecap(periodStart: recapStart.addingTimeInterval(1), at: cutoff) }
        #expect(engine.state == original)
    }

    @Test @MainActor func legacyVersionOneLoadsAndAcknowledgementPersists() throws {
        let legacy = Data(#"{"version":1,"timeZoneID":"Asia/Seoul","quests":[],"completions":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(AppState.self, from: legacy)
        #expect(decoded.version == 1)
        #expect(decoded.weeklyRecapAcknowledgedThrough == nil)
        var (engine, quest) = try fixture()
        try engine.complete(questID: quest.id, at: created)
        try engine.acknowledgeWeeklyRecap(periodStart: recapStart, at: cutoff)
        let repository = try SwiftDataStateRepository(inMemory: true)
        try repository.save(engine.state)
        #expect(try repository.load() == engine.state)
        #expect(try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(engine.state)) == engine.state)
    }

    @Test @MainActor func repositoryRejectsMisalignedAcknowledgementWithoutReplacingState() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let original = AppState(timeZoneID: "Asia/Seoul")
        try repository.save(original)
        var invalid = original
        invalid.weeklyRecapAcknowledgedThrough = created
        #expect(throws: QuestError.invalidState) { try repository.save(invalid) }
        #expect(try repository.load() == original)
    }
}
