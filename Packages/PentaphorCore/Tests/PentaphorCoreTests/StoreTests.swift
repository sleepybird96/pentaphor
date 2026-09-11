import Foundation
import Testing
@testable import PentaphorCore

@MainActor private final class FailingStorage: StateRepository {
    var fails = false
    var persisted: AppState?
    func load() throws -> AppState? { persisted }
    func save(_ state: AppState) throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        persisted = state
    }
}

@MainActor struct StoreTests {
    @Test func failedSaveDoesNotPublishPhantomQuestOrPoints() throws {
        let repository = FailingStorage()
        let store = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        repository.fails = true
        #expect(throws: CocoaError.self) {
            try store.transact { try $0.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(knowledge: 2), at: created) }
        }
        #expect(store.engine.state.quests.isEmpty)
        repository.fails = false
        let quest = try store.transact { try $0.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(knowledge: 2), at: created) }
        repository.fails = true
        #expect(throws: CocoaError.self) { try store.transact { try $0.complete(questID: quest.id, at: created) } }
        #expect(store.engine.totals == .zero)
        #expect(store.engine.state.completions.isEmpty)
    }
    @Test func relaunchUsesStoredTimeZoneAndRecordsInsteadOfNewDeviceTimeZone() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let first = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let quest = try first.transact { try $0.create(name: "수영", artID: "swimming", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created) }
        _ = try first.transact { try $0.complete(questID: quest.id, at: created) }
        let second = try QuestStore(repository: repository, timeZoneID: "America/New_York")
        #expect(second.engine.state.timeZoneID == "Asia/Seoul")
        #expect(second.engine.state.quests.count == 1)
        #expect(second.engine.totals.stamina == 2)
    }
    @Test func failedUndoKeepsOriginalRecordAndGrowth() throws {
        let repository = FailingStorage()
        let store = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let quest = try store.transact { try $0.create(name: "도전", artID: "climbing", cadence: .week, target: 1, rewards: StatPoints(courage: 2), at: created) }
        let record = try store.transact { try $0.complete(questID: quest.id, at: created) }
        repository.fails = true
        #expect(throws: CocoaError.self) { try store.transact { try $0.undo(completionID: record.completion.id) } }
        #expect(store.engine.totals.courage == 2)
        #expect(store.engine.state.completions.first?.isVoided == false)
    }
}
