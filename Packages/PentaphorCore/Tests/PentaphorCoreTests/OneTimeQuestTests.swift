import Foundation
import Testing
@testable import PentaphorCore

struct OneTimeQuestTests {
    private let later = instant("2027-02-08T03:00:00Z")

    @Test func completionHasNoCalendarResetAndLeavesActiveList() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "전시 보기", artID: "reading", cadence: .once, target: 1, rewards: StatPoints(courage: 2), at: created)
        #expect(engine.progress(for: quest, at: later).count == 0)
        #expect(engine.activeQuests == [quest])
        let result = try engine.complete(questID: quest.id, at: created)
        #expect(engine.progress(for: quest, at: later).count == 1)
        #expect(engine.progress(for: quest, at: later).achieved)
        #expect(engine.activeQuests.isEmpty)
        #expect(engine.archivedQuests.isEmpty)
        #expect(engine.state.quests == [quest])
        #expect(result.after == StatPoints(courage: 2))
        #expect(result.streak == 0)
        #expect(result.bonus == 0)
        #expect(engine.bonuses.isEmpty)
    }

    @Test func secondCompletionFailsAtomicallyButSameRequestIsIdempotent() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "한 걸음", artID: "running", cadence: .once, target: 1, rewards: StatPoints(stamina: 2), at: created)
        let first = try engine.complete(questID: quest.id, at: created)
        let original = engine.state
        _ = try engine.complete(questID: quest.id, at: later, requestID: first.completion.id)
        #expect(engine.state == original)
        #expect(throws: QuestError.alreadyCompleted) { try engine.complete(questID: quest.id, at: later) }
        #expect(engine.state == original)
    }

    @Test func undoRestoresEligibilityWithoutStreakRewards() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "한 번", artID: "running", cadence: .once, target: 1, rewards: StatPoints(perseverance: 2), at: created)
        let first = try engine.complete(questID: quest.id, at: created)
        try engine.undo(completionID: first.completion.id)
        #expect(engine.activeQuests == [quest])
        #expect(engine.totals == .zero)
        #expect(engine.progress(for: quest, at: later).count == 0)
        let next = try engine.complete(questID: quest.id, at: later)
        #expect(engine.activeQuests.isEmpty)
        #expect(next.after == StatPoints(perseverance: 2))
        #expect(next.bonus == 0 && next.streak == 0)
        #expect(engine.state.completions.count == 2)
        #expect(engine.state.completions[0].isVoided)
    }

    @Test(arguments: [0, 2, 99]) func oneTimeTargetMustEqualOne(target: Int) throws {
        var engine = emptyEngine()
        #expect(throws: QuestError.invalidTarget) {
            try engine.create(name: "한 번", artID: "reading", cadence: .once, target: target, rewards: .zero, at: created)
        }
        #expect(engine.state.quests.isEmpty)
        let quest = try engine.create(name: "한 번", artID: "reading", cadence: .once, target: 1, rewards: .zero, at: created)
        let original = engine.state
        #expect(throws: QuestError.invalidTarget) {
            try engine.update(id: quest.id, name: "변경", artID: "reading", cadence: .once, target: target, rewards: .zero, at: later)
        }
        #expect(engine.state == original)
    }

    @Test func cadenceCanChangeBeforeFirstRecordButNotAfterUndo() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 3, rewards: .zero, at: created)
        try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: .once, target: 1, rewards: .zero, at: later)
        let once = try #require(engine.activeQuests.first)
        #expect(engine.progress(for: once, at: later).target == 1)
        let result = try engine.complete(questID: quest.id, at: later)
        try engine.undo(completionID: result.completion.id)
        #expect(throws: QuestError.cadenceLocked) {
            try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: .month, target: 1, rewards: .zero, at: later)
        }
        try engine.update(id: quest.id, name: "새 메모", artID: quest.artID, cadence: .once, target: 1, rewards: StatPoints(knowledge: 2), at: later, notes: "준비물")
        let edited = try #require(engine.activeQuests.first)
        #expect(edited.notes == "준비물")
        #expect(edited.targetChanges.count == 1)
        #expect(try engine.complete(questID: quest.id, at: later).after == StatPoints(knowledge: 2))
    }

    @Test func archiveAndDeleteTakePrecedenceOverUndo() throws {
        for deleted in [false, true] {
            var engine = emptyEngine()
            let quest = try engine.create(name: "한 번", artID: "running", cadence: .once, target: 1, rewards: StatPoints(stamina: 2), at: created)
            try engine.setArchived(id: quest.id, archived: true)
            #expect(engine.activeQuests.isEmpty)
            #expect(throws: QuestError.archived) { try engine.complete(questID: quest.id, at: later) }
            try engine.setArchived(id: quest.id, archived: false)
            let result = try engine.complete(questID: quest.id, at: later)
            if deleted { try engine.delete(id: quest.id, at: later) }
            else { try engine.setArchived(id: quest.id, archived: true) }
            #expect(engine.totals == StatPoints(stamina: 2))
            try engine.undo(completionID: result.completion.id)
            #expect(engine.activeQuests.isEmpty)
            #expect(engine.totals == .zero)
        }
    }

    @Test func oneTimeCannotBeRecordedBeforeCreationOrAsPreviousWeek() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "한 번", artID: "reading", cadence: .once, target: 1, rewards: .zero, at: created)
        #expect(!engine.canRecordPreviousWeek(for: quest, at: later))
        #expect(throws: QuestError.graceExpired) { try engine.complete(questID: quest.id, at: later, previousWeek: true) }
        #expect(throws: QuestError.predatesQuest) { try engine.complete(questID: quest.id, at: created.addingTimeInterval(-1)) }
        #expect(engine.state.completions.isEmpty)
    }

    @MainActor @Test func diskReopenPreservesCompletedAndRestoredOneTimeQuests() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("once.store")
        var engine = emptyEngine()
        let once = try engine.create(name: "전시", artID: "reading", cadence: .once, target: 1, rewards: StatPoints(courage: 2), at: created)
        let weekly = try engine.create(name: "수영", artID: "swimming", cadence: .week, target: 3, rewards: .zero, at: created)
        let result = try engine.complete(questID: once.id, at: created)
        try SwiftDataStateRepository(url: url).save(engine.state)
        var reopened = QuestEngine(state: try #require(try SwiftDataStateRepository(url: url).load()))
        #expect(reopened.state == engine.state)
        #expect(reopened.activeQuests == [weekly])
        #expect(reopened.progress(for: once, at: later).achieved)
        try reopened.undo(completionID: result.completion.id)
        try SwiftDataStateRepository(url: url).save(reopened.state)
        let restored = QuestEngine(state: try #require(try SwiftDataStateRepository(url: url).load()))
        #expect(restored.activeQuests == [once, weekly])
        #expect(restored.totals == .zero)
    }

    @MainActor @Test(arguments: ["target", "duplicate-live", "period", "snapshot-target"])
    func invalidOneTimeStateCannotOverwriteSavedData(kind: String) throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        var engine = emptyEngine()
        let quest = try engine.create(name: "한 번", artID: "reading", cadence: .once, target: 1, rewards: .zero, at: created)
        let record = try engine.complete(questID: quest.id, at: created).completion
        try repository.save(engine.state)
        var invalid = engine.state
        switch kind {
        case "target": invalid.quests[0].targetChanges = [TargetChange(effectiveFrom: created, target: 2)]
        case "duplicate-live": invalid.completions.append(Completion(id: UUID(), questID: quest.id, recordedAt: later, period: record.period, target: 1, rewards: .zero, isVoided: false))
        case "period": invalid.completions[0] = Completion(id: record.id, questID: quest.id, recordedAt: created, period: engine.calculator.period(containing: created, cadence: .week), target: 1, rewards: .zero, isVoided: false)
        default: invalid.completions[0] = Completion(id: record.id, questID: quest.id, recordedAt: created, period: record.period, target: 2, rewards: .zero, isVoided: false)
        }
        #expect(throws: QuestError.invalidState) { try repository.save(invalid) }
        #expect(try repository.load() == engine.state)
    }
}
