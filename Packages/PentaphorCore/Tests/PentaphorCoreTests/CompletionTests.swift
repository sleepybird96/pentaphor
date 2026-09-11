import Foundation
import Testing
@testable import PentaphorCore

struct CompletionTests {
    @Test func graceEligibilityUsesInteractionTimeAcrossMidnight() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1, rewards: .zero, at: instant("2026-09-08T03:00:00Z"))
        let oldScreenDate = instant("2026-09-13T14:59:58Z")
        let tapDate = instant("2026-09-13T15:00:02Z")
        #expect(!engine.canRecordPreviousWeek(for: quest, at: oldScreenDate))
        #expect(engine.canRecordPreviousWeek(for: quest, at: tapDate))
        #expect(!engine.canRecordPreviousWeek(for: quest, at: instant("2026-09-14T00:00:00Z")))
        let newQuest = try engine.create(name: "새 퀘스트", artID: "running", cadence: .week, target: 1, rewards: .zero, at: tapDate)
        #expect(!engine.canRecordPreviousWeek(for: newQuest, at: tapDate))
        let monthly = try engine.create(name: "청소", artID: "running", cadence: .month, target: 1, rewards: .zero, at: created)
        #expect(!engine.canRecordPreviousWeek(for: monthly, at: tapDate))
    }
    @Test func completionPersistsSnapshotAndIdempotentRequestAddsOnlyOnce() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1, rewards: StatPoints(stamina: 1, charm: 1), at: created)
        let id = UUID()
        let result = try engine.complete(questID: quest.id, at: created, requestID: id)
        _ = try engine.complete(questID: quest.id, at: created, requestID: id)
        #expect(engine.state.completions.count == 1)
        #expect(result.before == .zero)
        #expect(result.after == StatPoints(stamina: 1, charm: 1))
        #expect(engine.totals == StatPoints(stamina: 1, charm: 1))
        #expect(engine.progress(for: quest, at: created).count == 1)
    }
    @Test func consecutiveWeeksAwardOncePerPeriodAndExtraCompletionsStillEarnBase() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1, rewards: StatPoints(stamina: 2), at: created)
        _ = try engine.complete(questID: quest.id, at: created)
        let second = try engine.complete(questID: quest.id, at: instant("2026-09-14T03:00:00Z"))
        #expect(second.bonus == 1)
        #expect(second.streak == 2)
        let extra = try engine.complete(questID: quest.id, at: instant("2026-09-15T03:00:00Z"))
        #expect(extra.bonus == 0)
        let third = try engine.complete(questID: quest.id, at: instant("2026-09-21T03:00:00Z"))
        #expect(third.streak == 3)
        #expect(engine.totals == StatPoints(stamina: 8, perseverance: 2))
        #expect(engine.bonuses.count == 2)
    }
    @Test func gapResetsMonthlyStreakAndQuestsDoNotShareBonuses() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "청소", artID: "cleaning", cadence: .month, target: 1, rewards: .zero, at: created)
        _ = try engine.complete(questID: quest.id, at: created)
        _ = try engine.complete(questID: quest.id, at: instant("2026-10-01T03:00:00Z"))
        _ = try engine.complete(questID: quest.id, at: instant("2026-12-01T03:00:00Z"))
        let another = try engine.create(name: "다른 청소", artID: "cleaning", cadence: .month, target: 1, rewards: .zero, at: instant("2027-01-01T03:00:00Z"))
        _ = try engine.complete(questID: another.id, at: instant("2027-01-01T03:00:00Z"))
        #expect(engine.totals.perseverance == 1)
        #expect(engine.bonuses.count == 1)
    }
    @Test func graceSelectionRecordsPreviousWeekWhileDefaultUsesCurrentWeek() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1, rewards: .zero, at: created)
        let monday = instant("2026-09-13T23:59:59Z")
        let current = try engine.complete(questID: quest.id, at: monday)
        let previous = try engine.complete(questID: quest.id, at: monday, previousWeek: true)
        #expect(current.completion.period.start == instant("2026-09-13T15:00:00Z"))
        #expect(previous.completion.period.start == instant("2026-09-06T15:00:00Z"))
        #expect(engine.totals.perseverance == 1)
        #expect(previous.bonus == 1) // filling the earlier period can qualify the already-complete current one
        #expect(throws: QuestError.graceExpired) {
            try engine.complete(questID: quest.id, at: instant("2026-09-14T00:00:00Z"), previousWeek: true)
        }
        #expect(engine.state.completions.count == 2)
    }
    @Test func graceRejectsMonthlyAndQuestsCreatedThisWeek() throws {
        var engine = emptyEngine()
        let monday = instant("2026-09-13T16:00:00Z")
        let new = try engine.create(name: "새 퀘스트", artID: "reading", cadence: .week, target: 1, rewards: .zero, at: monday)
        #expect(throws: QuestError.predatesQuest) { try engine.complete(questID: new.id, at: monday, previousWeek: true) }
        let monthly = try engine.create(name: "월간", artID: "reading", cadence: .month, target: 1, rewards: .zero, at: created)
        #expect(throws: QuestError.graceExpired) { try engine.complete(questID: monthly.id, at: monday, previousWeek: true) }
        #expect(engine.state.completions.isEmpty)
    }
    @Test func undoEarlierQualificationRemovesDependentBonusesButNotLaterBasePoints() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "도전", artID: "climbing", cadence: .week, target: 1, rewards: StatPoints(courage: 2), at: created)
        let first = try engine.complete(questID: quest.id, at: created)
        _ = try engine.complete(questID: quest.id, at: instant("2026-09-14T03:00:00Z"))
        _ = try engine.complete(questID: quest.id, at: instant("2026-09-21T03:00:00Z"))
        try engine.undo(completionID: first.completion.id)
        try engine.undo(completionID: first.completion.id)
        #expect(engine.totals == StatPoints(perseverance: 1, courage: 4))
        #expect(engine.state.completions.count == 3)
        #expect(engine.state.completions.first?.isVoided == true)
        #expect(engine.progress(for: quest, at: created).count == 0)
        #expect(throws: QuestError.duplicateRequest) { try engine.complete(questID: quest.id, at: created, requestID: first.completion.id) }
    }
}
