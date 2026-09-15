import Foundation
import Testing
@testable import PentaphorCore

struct CurrentTargetEditTests {
    @Test(arguments: [Cadence.week, .month])
    func targetSevenToFourteenAppliesAfterActivity(cadence: Cadence) throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: cadence, target: 7, rewards: StatPoints(knowledge: 2), at: created)
        let first = try engine.complete(questID: quest.id, at: created).completion
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: cadence, target: 14, rewards: StatPoints(courage: 1), at: created)
        let updated = try #require(engine.activeQuests.first)
        #expect(engine.progress(for: updated, at: created).target == 14)
        #expect(engine.progress(for: updated, at: created).count == 1)
        let second = try engine.complete(questID: quest.id, at: created.addingTimeInterval(60)).completion
        #expect(engine.state.completions.map(\.target) == [14, 14])
        #expect(engine.state.completions[0].id == first.id)
        #expect(engine.state.completions[0].recordedAt == first.recordedAt)
        #expect(engine.state.completions[0].period == first.period)
        #expect(engine.state.completions[0].rewards == first.rewards)
        #expect(second.rewards == StatPoints(courage: 1))
        #expect(engine.totals == StatPoints(knowledge: 2, courage: 1))
        let reloaded = QuestEngine(state: try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(engine.state)))
        #expect(reloaded.progress(for: reloaded.activeQuests[0], at: created).target == 14)
    }

    @Test(arguments: [Cadence.week, .month])
    func voidedOnlyActivityUsesEditedTargetForNextRecord(cadence: Cadence) throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: cadence, target: 7, rewards: .zero, at: created)
        let record = try engine.complete(questID: quest.id, at: created).completion
        try engine.undo(completionID: record.id)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: cadence, target: 14, rewards: .zero, at: created)
        #expect(engine.progress(for: engine.activeQuests[0], at: created).target == 14)
        #expect(engine.progress(for: engine.activeQuests[0], at: created).count == 0)
        #expect(engine.state.completions[0].isVoided)
        #expect(engine.state.completions[0].target == 14)
        #expect(try engine.complete(questID: quest.id, at: created).completion.target == 14)
    }

    @Test(arguments: [Cadence.week, .month])
    func savingPreviouslyScheduledTargetRepairsCurrentPeriod(cadence: Cadence) throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: cadence, target: 7, rewards: .zero, at: created)
        let record = try engine.complete(questID: quest.id, at: created).completion
        var legacy = engine.state
        legacy.quests[0].targetChanges.append(TargetChange(effectiveFrom: record.period.end, target: 14))
        engine = QuestEngine(state: legacy)
        #expect(engine.progress(for: engine.activeQuests[0], at: created).target == 7)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: cadence, target: 14, rewards: .zero, at: created)
        #expect(engine.progress(for: engine.activeQuests[0], at: created).target == 14)
        #expect(engine.progress(for: engine.activeQuests[0], at: record.period.end).target == 14)
        #expect(engine.state.quests[0].targetChanges == [TargetChange(effectiveFrom: record.period.start, target: 14)])
    }

    @Test(arguments: [Cadence.week, .month])
    func loweringAndRaisingTargetRecalculatesGoalBonusAndReminders(cadence: Cadence) throws {
        var engine = emptyEngine()
        let priorDate = instant("2026-08-31T03:00:00Z")
        let now = instant("2026-09-07T10:00:00Z")
        let quest = try engine.create(name: "독서", artID: "reading", cadence: cadence, target: 2, rewards: StatPoints(knowledge: 1), at: priorDate)
        for _ in 0..<2 { try engine.complete(questID: quest.id, at: priorDate) }
        try engine.complete(questID: quest.id, at: now)
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [2], hour: 20, minute: 0))
        #expect(engine.bonuses.isEmpty)
        #expect(QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 1).count == 1)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: cadence, target: 1, rewards: StatPoints(knowledge: 1), at: now)
        #expect(engine.progress(for: engine.activeQuests[0], at: now).achieved)
        #expect(engine.bonuses.count == 1)
        #expect(engine.totals == StatPoints(knowledge: 3, perseverance: 1))
        #expect(QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 1).isEmpty)
        let recapPeriod = engine.calculator.period(containing: now, cadence: .week)
        #expect(WeeklyRecapBuilder.build(engine: engine, period: recapPeriod)?.streakBonus == 1)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: cadence, target: 14, rewards: StatPoints(knowledge: 1), at: now)
        #expect(!engine.progress(for: engine.activeQuests[0], at: now).achieved)
        #expect(engine.bonuses.isEmpty)
        #expect(engine.totals == StatPoints(knowledge: 3))
        let reminders = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 1)
        #expect(reminders.count == 1)
        #expect(reminders.first?.body.contains("13") == true)
        #expect(WeeklyRecapBuilder.build(engine: engine, period: recapPeriod)?.streakBonus == 0)
    }

    @Test(arguments: [Cadence.week, .month])
    func currentEditPreservesClosedPeriodSnapshots(cadence: Cadence) throws {
        var engine = emptyEngine()
        let priorDate = instant("2026-08-31T03:00:00Z")
        let quest = try engine.create(name: "독서", artID: "reading", cadence: cadence, target: 7, rewards: StatPoints(knowledge: 2), at: priorDate)
        let prior = try engine.complete(questID: quest.id, at: priorDate).completion
        let voided = try engine.complete(questID: quest.id, at: priorDate).completion
        try engine.undo(completionID: voided.id)
        let priorRecords = engine.state.completions
        try engine.complete(questID: quest.id, at: created)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: cadence, target: 14, rewards: .zero, at: created)
        #expect(Array(engine.state.completions.prefix(2)) == priorRecords)
        #expect(engine.target(for: engine.activeQuests[0], period: prior.period) == 7)
        #expect(engine.progress(for: engine.activeQuests[0], at: created).target == 14)
    }

    @Test func mondayEditWithCurrentActivityPreservesPriorWeekGraceTarget() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 7, rewards: .zero, at: created)
        let monday = instant("2026-09-13T16:00:00Z")
        try engine.complete(questID: quest.id, at: monday)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: .week, target: 14, rewards: .zero, at: monday)
        #expect(try engine.complete(questID: quest.id, at: monday, previousWeek: true).completion.target == 7)
        #expect(engine.progress(for: engine.activeQuests[0], at: monday).target == 14)
    }
}
