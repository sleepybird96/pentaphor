import Foundation
import Testing
@testable import PentaphorCore

struct QuestDeletionTests {
    @Test func deletionPreservesHistoryPointsAndStreakButCannotBeRestoredOrEdited() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(knowledge: 2), at: created)
        _ = try engine.complete(questID: quest.id, at: created)
        let nextWeek = instant("2026-09-14T03:00:00Z")
        _ = try engine.complete(questID: quest.id, at: nextWeek)
        let other = try engine.create(name: "수영", artID: "swimming", cadence: .week, target: 1, rewards: .zero, at: created)
        let records = engine.state.completions
        let bonuses = engine.bonuses.map(\.id)
        #expect(engine.totals == StatPoints(knowledge: 4, perseverance: 1))
        try engine.delete(id: quest.id, at: nextWeek)
        #expect(engine.activeQuests.map(\.id) == [other.id])
        #expect(engine.archivedQuests.isEmpty)
        #expect(engine.state.quests.first?.name == "독서")
        #expect(engine.state.quests.first?.deletedAt == nextWeek)
        #expect(engine.state.completions == records)
        #expect(engine.bonuses.map(\.id) == bonuses)
        #expect(engine.totals == StatPoints(knowledge: 4, perseverance: 1))
        let deletedState = engine.state
        #expect(throws: QuestError.notFound) { try engine.complete(questID: quest.id, at: nextWeek) }
        #expect(throws: QuestError.notFound) { try engine.setArchived(id: quest.id, archived: false) }
        #expect(throws: QuestError.notFound) {
            try engine.update(id: quest.id, name: "수정", artID: "reading", cadence: .week, target: 1, rewards: .zero, at: nextWeek)
        }
        #expect(throws: QuestError.notFound) { try engine.delete(id: UUID(), at: nextWeek) }
        #expect(engine.state == deletedState)
    }

    @MainActor @Test func deletingArchivedQuestPersistsOnDiskWithItsRecords() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("delete.store")
        var records: [Completion] = []
        do {
            let store = try QuestStore(repository: SwiftDataStateRepository(url: url), timeZoneID: "Asia/Seoul")
            let quest = try store.transact { try $0.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(knowledge: 2), at: created) }
            _ = try store.transact { try $0.complete(questID: quest.id, at: created) }
            records = store.engine.state.completions
            try store.transact { try $0.setArchived(id: quest.id, archived: true) }
            try store.transact { try $0.delete(id: quest.id, at: created) }
        }
        let reopened = try QuestStore(repository: SwiftDataStateRepository(url: url))
        #expect(reopened.engine.activeQuests.isEmpty)
        #expect(reopened.engine.archivedQuests.isEmpty)
        #expect(reopened.engine.state.completions == records)
        #expect(reopened.engine.totals == StatPoints(knowledge: 2))
        #expect(reopened.engine.state.quests.first?.deletedAt == created)
    }
}
