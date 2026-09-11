import Foundation
import SwiftData
import Testing
@testable import PentaphorCore

@MainActor struct RepositoryTests {
    @Test(arguments: ["duplicate-completion", "duplicate-quest", "negative-reward", "invalid-target", "missing-quest", "snapshot-reward", "snapshot-target", "unknown-art", "empty-name", "empty-targets"])
    func rejectsSemanticallyInvalidStateWithoutOverwriting(kind: String) throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        var engine = emptyEngine()
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1, rewards: StatPoints(stamina: 2), at: created)
        _ = try engine.complete(questID: quest.id, at: created)
        let original = engine.state
        try repository.save(original)
        var invalid = original
        switch kind {
        case "duplicate-completion": invalid.completions.append(invalid.completions[0])
        case "duplicate-quest": invalid.quests.append(invalid.quests[0])
        case "negative-reward": invalid.quests[0].rewards.stamina = -1
        case "missing-quest": invalid.quests = []
        case "snapshot-reward":
            let record = invalid.completions[0]
            invalid.completions[0] = Completion(id: record.id, questID: record.questID, recordedAt: record.recordedAt, period: record.period, target: record.target, rewards: StatPoints(stamina: 3), isVoided: false)
        case "snapshot-target":
            let record = invalid.completions[0]
            invalid.completions[0] = Completion(id: record.id, questID: record.questID, recordedAt: record.recordedAt, period: record.period, target: 0, rewards: record.rewards, isVoided: false)
        case "unknown-art": invalid.quests[0].artID = "missing"
        case "empty-name": invalid.quests[0].name = " "
        case "empty-targets": invalid.quests[0].targetChanges = []
        default: invalid.quests[0].targetChanges = [TargetChange(effectiveFrom: created, target: 0)]
        }
        #expect(throws: QuestError.invalidState) { try repository.save(invalid) }
        #expect(try repository.load() == original)
    }
    @Test func futureVersionOnDiskBlocksLoadAndOverwrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("future.store")
        var future = AppState(timeZoneID: "Asia/Seoul")
        future.version = 999
        let payload = try JSONEncoder().encode(future)
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
    @Test func diskReopenPreservesSnapshotsVoidsAndTimeZone() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("records.store")
        var engine = emptyEngine()
        let quest = try engine.create(name: "나만의 독서", artID: "reading", cadence: .week, target: 2, rewards: StatPoints(knowledge: 2), at: created)
        let record = try engine.complete(questID: quest.id, at: created)
        try engine.undo(completionID: record.completion.id)
        try engine.update(id: quest.id, name: "나만의 독서", artID: "reading", cadence: .week, target: 1, rewards: .zero, at: created)
        do {
            let repository = try SwiftDataStateRepository(url: url)
            try repository.save(engine.state)
        }
        let reopened = try SwiftDataStateRepository(url: url)
        let loaded = try #require(try reopened.load())
        #expect(loaded == engine.state)
        #expect(loaded.timeZoneID == "Asia/Seoul")
        #expect(loaded.completions.first?.isVoided == true)
    }
    @Test func secondSaveReplacesStateRatherThanCreatingMultipleRoots() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        var engine = emptyEngine()
        try repository.save(engine.state)
        _ = try engine.create(name: "운동", artID: "running", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created)
        try repository.save(engine.state)
        #expect(try repository.load()?.quests.count == 1)
    }
    @Test func rejectsUnknownVersionWithoutReplacingExistingData() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let original = AppState(timeZoneID: "Asia/Seoul")
        try repository.save(original)
        var invalid = original
        invalid.version = 999
        #expect(throws: QuestError.invalidState) { try repository.save(invalid) }
        #expect(try repository.load() == original)
    }
    @Test func corruptPayloadIsNotTreatedAsEmptyAndRemainsOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("records.store")
        let corrupt = Data("not a valid record".utf8)
        do {
            let container = try ModelContainer(for: StateDocument.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            context.insert(StateDocument(payload: corrupt))
            try context.save()
        }
        let repository = try SwiftDataStateRepository(url: url)
        #expect(throws: QuestError.invalidState) { try repository.load() }
        let verify = try ModelContainer(for: StateDocument.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        #expect(try ModelContext(verify).fetch(FetchDescriptor<StateDocument>()).first?.payload == corrupt)
    }
}
