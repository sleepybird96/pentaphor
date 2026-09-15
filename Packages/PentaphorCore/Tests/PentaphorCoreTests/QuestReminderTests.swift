import Foundation
import SwiftData
import Testing
@testable import PentaphorCore

@MainActor struct QuestReminderTests {
    @Test func globalReminderSwitchPersistsAndPreservesQuestSchedules() throws {
        var engine = try remindedEngine()
        let original = engine.state
        #expect(engine.preferences.remindersEnabled)
        var preferences = engine.preferences
        preferences.remindersEnabled = false
        try engine.updatePreferences(preferences)
        let saved = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(engine.state))
        #expect(!QuestEngine(state: saved).preferences.remindersEnabled)
        #expect(saved.quests == original.quests)
        #expect(QuestReminderPlanner.plan(engine: QuestEngine(state: saved), now: created).isEmpty)
        preferences.remindersEnabled = true
        try engine.updatePreferences(preferences)
        #expect(!QuestReminderPlanner.plan(engine: engine, now: created).isEmpty)
        let legacy = Data(#"{"nickname":"","hasCompletedOnboarding":true,"hasCreatedFirstQuest":true,"hapticsEnabled":true,"simplifiedEffects":false}"#.utf8)
        #expect(try JSONDecoder().decode(ExperiencePreferences.self, from: legacy).remindersEnabled)
    }

    @Test func rejectsInvalidDecodedReminderWithoutOverwritingSavedState() throws {
        var engine = emptyEngine()
        _ = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 2, rewards: .zero, at: created)
        let repository = try SwiftDataStateRepository(inMemory: true)
        try repository.save(engine.state)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(engine.state)) as? [String: Any])
        var quests = try #require(json["quests"] as? [[String: Any]])
        quests[0]["reminder"] = ["weekdays": [2, 2], "hour": 20, "minute": 0]
        json["quests"] = quests
        let decoded = try JSONDecoder().decode(AppState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: QuestError.invalidState) { try repository.save(decoded) }
        #expect(try repository.load() == engine.state)
    }

    @Test func invalidReminderOnDiskBlocksLoadAndPreservesPayload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("reminders.store")
        var state = try remindedEngine().state
        state.quests[0].reminder = QuestReminder(weekdays: [2], hour: 24, minute: 0)
        let payload = try JSONEncoder().encode(state)
        do {
            let container = try ModelContainer(for: StateDocument.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            context.insert(StateDocument(payload: payload))
            try context.save()
        }
        let repository = try SwiftDataStateRepository(url: url)
        #expect(throws: QuestError.invalidState) { try repository.load() }
        #expect(throws: QuestError.invalidState) { try repository.save(AppState(timeZoneID: "Asia/Seoul")) }
        let verify = try ModelContainer(for: StateDocument.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        #expect(try ModelContext(verify).fetch(FetchDescriptor<StateDocument>()).first?.payload == payload)
    }

    @Test func legacyStateDefaultsOffAndReminderRoundTrips() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 2, rewards: .zero, at: created)
        let legacy = try JSONEncoder().encode(engine.state)
        #expect(!String(decoding: legacy, as: UTF8.self).contains("reminder"))
        #expect(try JSONDecoder().decode(AppState.self, from: legacy).quests[0].reminder == nil)
        #expect(QuestReminderPlanner.plan(engine: engine, now: created).isEmpty)
        let reminder = QuestReminder(weekdays: [2, 4, 6], hour: 20, minute: 15)
        try engine.updateReminder(id: quest.id, reminder: reminder)
        let repository = try SwiftDataStateRepository(inMemory: true)
        try repository.save(engine.state)
        #expect(try repository.load()?.quests[0].reminder == reminder)
        try engine.update(id: quest.id, name: "새 독서", artID: "reading", cadence: .week, target: 3, rewards: .zero, at: created)
        #expect(engine.state.quests[0].reminder == reminder)
        try engine.updateReminder(id: quest.id, reminder: nil)
        #expect(QuestReminderPlanner.plan(engine: engine, now: created).isEmpty)
    }

    @Test(arguments: [
        QuestReminder(weekdays: [], hour: 20, minute: 0),
        QuestReminder(weekdays: [2, 2], hour: 20, minute: 0),
        QuestReminder(weekdays: [0], hour: 20, minute: 0),
        QuestReminder(weekdays: [8], hour: 20, minute: 0),
        QuestReminder(weekdays: [2], hour: -1, minute: 0),
        QuestReminder(weekdays: [2], hour: 24, minute: 0),
        QuestReminder(weekdays: [2], hour: 20, minute: -1),
        QuestReminder(weekdays: [2], hour: 20, minute: 60)
    ])
    func invalidReminderFailsAtomically(reminder: QuestReminder) throws {
        var engine = try remindedEngine()
        let before = engine.state
        #expect(!reminder.isValid)
        #expect(throws: QuestError.invalidReminder) { try engine.updateReminder(id: before.quests[0].id, reminder: reminder) }
        #expect(engine.state == before)
        var invalid = before
        invalid.quests[0].reminder = reminder
        #expect(throws: QuestError.invalidState) { try SwiftDataStateRepository(inMemory: true).save(invalid) }
        #expect(QuestReminderPlanner.plan(engine: QuestEngine(state: invalid), now: created).isEmpty)
    }

    @Test func selectedDaysUseSavedTimeZoneAndExcludeElapsedTimes() throws {
        let engine = try remindedEngine(days: [2, 4, 6])
        let now = instant("2026-09-14T10:59:59Z")
        let plan = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 7)
        #expect(plan.map(\.fireDate) == [instant("2026-09-14T11:00:00Z"), instant("2026-09-16T11:00:00Z"), instant("2026-09-18T11:00:00Z")])
        #expect(plan.first?.title == "독서")
        #expect(plan.first?.body.contains("2") == true)
        #expect(plan.first?.id == "pentaphor.quest.\(engine.state.quests[0].id.uuidString).1789383600")
        #expect(QuestReminderPlanner.plan(engine: engine, now: instant("2026-09-14T11:00:00Z"), horizonDays: 1).isEmpty)
    }

    @Test func achievedWeekStopsCurrentDatesAndUndoRestoresThem() throws {
        var engine = try remindedEngine(days: [2, 4, 6])
        let id = engine.state.quests[0].id
        let now = instant("2026-09-14T10:00:00Z")
        _ = try engine.complete(questID: id, at: now)
        let second = try engine.complete(questID: id, at: now)
        let plan = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 14)
        #expect(plan.map(\.fireDate) == [instant("2026-09-21T11:00:00Z"), instant("2026-09-23T11:00:00Z"), instant("2026-09-25T11:00:00Z")])
        #expect(plan.allSatisfy { $0.body.contains("2") })
        try engine.undo(completionID: second.completion.id)
        let restored = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 14)
        #expect(restored.count == 6)
        #expect(restored.first?.body.contains("1") == true)
    }

    @Test func mondayBeforeNineRemindsForNewWeekDespiteGrace() throws {
        var engine = try remindedEngine(days: [2], hour: 8)
        let id = engine.state.quests[0].id
        let sunday = instant("2026-09-13T10:00:00Z")
        _ = try engine.complete(questID: id, at: sunday)
        _ = try engine.complete(questID: id, at: sunday)
        let monday = instant("2026-09-13T22:00:00Z")
        #expect(engine.canRecordPreviousWeek(for: engine.state.quests[0], at: monday))
        #expect(QuestReminderPlanner.plan(engine: engine, now: monday, horizonDays: 1).map(\.fireDate) == [instant("2026-09-13T23:00:00Z")])
    }

    @Test func monthlyGoalResumesInNextMonth() throws {
        var engine = try remindedEngine(cadence: .month, days: [2, 5], target: 1)
        let now = instant("2026-09-28T10:00:00Z")
        _ = try engine.complete(questID: engine.state.quests[0].id, at: now)
        let plan = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 7)
        #expect(plan.map(\.fireDate) == [instant("2026-10-01T11:00:00Z")])
        #expect(plan.first?.body.contains("1") == true)
    }

    @Test func onceCompletionUndoArchiveRestoreAndDeleteReconcileEligibility() throws {
        var engine = try remindedEngine(cadence: .once, days: [2], target: 1)
        let id = engine.state.quests[0].id
        let now = instant("2026-09-14T10:00:00Z")
        #expect(!QuestReminderPlanner.plan(engine: engine, now: now).isEmpty)
        let result = try engine.complete(questID: id, at: now)
        #expect(QuestReminderPlanner.plan(engine: engine, now: now).isEmpty)
        try engine.undo(completionID: result.completion.id)
        #expect(!QuestReminderPlanner.plan(engine: engine, now: now).isEmpty)
        try engine.setArchived(id: id, archived: true)
        #expect(QuestReminderPlanner.plan(engine: engine, now: now).isEmpty)
        try engine.setArchived(id: id, archived: false)
        #expect(!QuestReminderPlanner.plan(engine: engine, now: now).isEmpty)
        try engine.delete(id: id, at: now)
        #expect(QuestReminderPlanner.plan(engine: engine, now: now).isEmpty)
        #expect(throws: QuestError.notFound) { try engine.updateReminder(id: id, reminder: nil) }
        #expect(throws: QuestError.notFound) { try engine.updateReminder(id: UUID(), reminder: nil) }
    }

    @Test func editsUseUpdatedCurrentAndFutureTargetWithUpdatedTitleAndTime() throws {
        var engine = try remindedEngine(days: [2])
        let id = engine.state.quests[0].id
        let now = instant("2026-09-14T10:00:00Z")
        _ = try engine.complete(questID: id, at: now)
        try engine.update(id: id, name: "수정한 독서", artID: "reading", cadence: .week, target: 5, rewards: .zero, at: now)
        try engine.updateReminder(id: id, reminder: QuestReminder(weekdays: [2], hour: 21, minute: 30))
        let plan = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 14)
        #expect(plan.map(\.fireDate) == [instant("2026-09-14T12:30:00Z"), instant("2026-09-21T12:30:00Z")])
        #expect(plan.allSatisfy { $0.title == "수정한 독서" })
        try #require(plan.count == 2)
        #expect(plan[0].body.contains("4"))
        #expect(plan[1].body.contains("5"))
    }

    @Test func daylightSavingGapUsesNextTimeAndOverlapUsesFirstTimeOnly() throws {
        let spring = try remindedEngine(timeZone: "America/New_York", days: [1], hour: 2, minute: 30, creation: "2026-03-01T00:00:00Z")
        #expect(QuestReminderPlanner.plan(engine: spring, now: instant("2026-03-08T05:00:00Z"), horizonDays: 1).map(\.fireDate) == [instant("2026-03-08T07:00:00Z")])
        let fall = try remindedEngine(timeZone: "America/New_York", days: [1], hour: 1, minute: 30)
        #expect(QuestReminderPlanner.plan(engine: fall, now: instant("2026-11-01T04:00:00Z"), horizonDays: 1).map(\.fireDate) == [instant("2026-11-01T05:30:00Z")])
        #expect(QuestReminderPlanner.plan(engine: fall, now: instant("2026-11-01T05:45:00Z"), horizonDays: 1).isEmpty)
    }

    @Test func midnightDSTGapDoesNotSkipNextDaysEarlyReminder() throws {
        let engine = try remindedEngine(timeZone: "America/Santiago", days: [2], hour: 0, minute: 30, creation: "2026-09-01T00:00:00Z")
        // Sunday starts at 01:00 after the spring gap; Monday has an ordinary midnight.
        let plan = QuestReminderPlanner.plan(engine: engine, now: instant("2026-09-06T12:00:00Z"), horizonDays: 2)
        #expect(plan.map(\.fireDate) == [instant("2026-09-07T03:30:00Z")])
    }

    @Test func earliestGlobalLimitAndHorizonAreBoundedAndDeterministic() throws {
        var engine = QuestEngine(state: AppState(timeZoneID: "Asia/Seoul"))
        for suffix in ["3", "1", "2"] {
            let id = UUID(uuidString: "00000000-0000-0000-0000-00000000000" + suffix)!
            _ = try engine.create(name: suffix, artID: "reading", cadence: .week, target: 2, rewards: .zero, at: created, id: id)
            try engine.updateReminder(id: id, reminder: QuestReminder(weekdays: [1, 2, 3, 4, 5, 6, 7], hour: 20, minute: 0))
        }
        let now = instant("2026-09-14T10:00:00Z")
        let plan = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 100, limit: 100)
        #expect(plan.count == 60)
        #expect(plan.prefix(3).map(\.title) == ["1", "2", "3"])
        #expect(plan.last?.fireDate == instant("2026-10-03T11:00:00Z"))
        #expect(Set(plan.map(\.id)).count == 60)
        #expect(QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 1, limit: 2).map(\.title) == ["1", "2"])
        #expect(QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 0).isEmpty)
        #expect(QuestReminderPlanner.plan(engine: engine, now: now, limit: -1).isEmpty)
        engine = try remindedEngine(days: [1, 2, 3, 4, 5, 6, 7])
        let horizon = QuestReminderPlanner.plan(engine: engine, now: now, horizonDays: 100)
        #expect(horizon.count == 42)
        #expect(horizon.last?.fireDate == instant("2026-10-25T11:00:00Z"))
    }

    private func remindedEngine(timeZone: String = "Asia/Seoul", cadence: Cadence = .week, days: [Int] = [2], hour: Int = 20, minute: Int = 0, target: Int = 2, creation: String = "2026-09-07T00:00:00Z") throws -> QuestEngine {
        var engine = QuestEngine(state: AppState(timeZoneID: timeZone))
        let quest = try engine.create(name: "독서", artID: "reading", cadence: cadence, target: target, rewards: .zero, at: instant(creation))
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: days, hour: hour, minute: minute))
        return engine
    }
}
