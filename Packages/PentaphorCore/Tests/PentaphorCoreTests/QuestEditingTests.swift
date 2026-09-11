import Foundation
import Testing
@testable import PentaphorCore

struct QuestEditingTests {
    @Test func editedRewardDoesNotRewriteHistoryAndTargetWaitsForNextPeriod() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 2, rewards: StatPoints(knowledge: 2), at: created)
        _ = try engine.complete(questID: quest.id, at: created)
        try engine.update(id: quest.id, name: "새 이름", artID: "studying", cadence: .week, target: 1, rewards: StatPoints(courage: 2), at: created)
        let updated = try #require(engine.state.quests.first)
        #expect(updated.name == "새 이름")
        #expect(updated.artID == "studying")
        #expect(engine.progress(for: updated, at: created).target == 2)
        #expect(engine.progress(for: updated, at: instant("2026-09-14T03:00:00Z")).target == 1)
        _ = try engine.complete(questID: quest.id, at: created)
        #expect(engine.totals == StatPoints(knowledge: 2, courage: 2))
        #expect(engine.state.completions.map(\.target) == [2,2])
    }
    @Test func noActivityAllowsImmediateTargetAndCadenceChange() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "청소", artID: "cleaning", cadence: .week, target: 3, rewards: .zero, at: created)
        try engine.update(id: quest.id, name: "청소", artID: "cleaning", cadence: .month, target: 1, rewards: .zero, at: created)
        let updated = try #require(engine.state.quests.first)
        #expect(updated.cadence == .month)
        #expect(engine.progress(for: updated, at: created).target == 1)
    }
    @Test func cadenceChangeAfterRecordFailsAtomicallyEvenIfRecordWasVoided() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "청소", artID: "cleaning", cadence: .week, target: 3, rewards: .zero, at: created)
        let event = try engine.complete(questID: quest.id, at: created)
        try engine.undo(completionID: event.completion.id)
        let before = engine.state
        #expect(throws: QuestError.cadenceLocked) {
            try engine.update(id: quest.id, name: "바뀌면 안 돼", artID: "reading", cadence: .month, target: 1, rewards: .zero, at: created)
        }
        #expect(engine.state == before)
    }
    @Test func archivePreservesGrowthBlocksNewRecordsAndRestores() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(knowledge: 2), at: created)
        let event = try engine.complete(questID: quest.id, at: created)
        try engine.setArchived(id: quest.id, archived: true)
        #expect(engine.state.quests.first?.isArchived == true)
        #expect(engine.totals.knowledge == 2)
        #expect(throws: QuestError.archived) { try engine.complete(questID: quest.id, at: created) }
        try engine.undo(completionID: event.completion.id)
        #expect(engine.totals == .zero)
        try engine.setArchived(id: quest.id, archived: false)
        _ = try engine.complete(questID: quest.id, at: created)
        #expect(engine.totals.knowledge == 2)
    }
    @Test func duplicateQuestIdentifierAndInvalidEditDoNotMutate() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: .zero, at: created)
        #expect(throws: QuestError.duplicateRequest) {
            try engine.create(name: "두번째", artID: "reading", cadence: .week, target: 1, rewards: .zero, at: created, id: quest.id)
        }
        #expect(throws: QuestError.invalidRewards) {
            try engine.update(id: quest.id, name: "변경", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(courage: 3), at: created)
        }
        #expect(engine.state.quests.count == 1)
        #expect(engine.state.quests.first?.name == "독서")
    }
    @Test func graceUsesPreviousTargetAfterCurrentPeriodEdit() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 2, rewards: .zero, at: created)
        let monday = instant("2026-09-13T16:00:00Z")
        try engine.update(id: quest.id, name: "달리기", artID: "running", cadence: .week, target: 4, rewards: .zero, at: monday)
        let old = try engine.complete(questID: quest.id, at: monday, previousWeek: true)
        let current = try engine.complete(questID: quest.id, at: monday)
        #expect(old.completion.target == 2)
        #expect(current.completion.target == 4)
    }
}
