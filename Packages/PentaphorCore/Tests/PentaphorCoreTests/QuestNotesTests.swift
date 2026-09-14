import Foundation
import SwiftData
import Testing
@testable import PentaphorCore

struct QuestNotesTests {
    @Test func multilineNotesCanBeEditedAndClearedWithoutChangingGrowth() throws {
        var engine = emptyEngine()
        let originalNotes = "준비물: 운동화 👟\n\n천천히 30분 달리기\n"
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created, notes: originalNotes)
        #expect(quest.notes == originalNotes)
        _ = try engine.complete(questID: quest.id, at: created)
        let records = engine.state.completions
        try engine.update(id: quest.id, name: "달리기", artID: "running", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created, notes: "스트레칭 먼저\n무리하지 않기")
        #expect(engine.state.quests[0].notes == "스트레칭 먼저\n무리하지 않기")
        try engine.update(id: quest.id, name: "저녁 달리기", artID: "running", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created)
        #expect(engine.state.quests[0].notes == "스트레칭 먼저\n무리하지 않기")
        try engine.update(id: quest.id, name: "저녁 달리기", artID: "running", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created, notes: "")
        #expect(engine.state.quests[0].notes == nil)
        #expect(engine.state.completions == records)
        #expect(engine.totals == StatPoints(stamina: 2))
        #expect(engine.progress(for: engine.state.quests[0], at: created).count == 1)
    }

    @MainActor @Test func legacyDiskRecordsAcceptNotesAndReopenWithoutLosingHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("legacy.store")
        let legacy = Data(#"""
        {"version":1,"timeZoneID":"Asia/Seoul","quests":[{"id":"11111111-1111-1111-1111-111111111111","name":"기존 독서","artID":"reading","cadence":"week","createdAt":0,"isArchived":false,"rewards":{"stamina":0,"knowledge":2,"perseverance":0,"charm":0,"courage":0},"targetChanges":[{"effectiveFrom":-32400,"target":1}]}],"completions":[{"id":"22222222-2222-2222-2222-222222222222","questID":"11111111-1111-1111-1111-111111111111","recordedAt":3600,"period":{"start":-32400,"end":572400,"cadence":"week"},"target":1,"rewards":{"stamina":0,"knowledge":2,"perseverance":0,"charm":0,"courage":0},"isVoided":false}]}
        """#.utf8)
        do {
            let container = try ModelContainer(for: StateDocument.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            context.insert(StateDocument(payload: legacy))
            try context.save()
        }
        let notes = "읽을 책 📚\n1장부터 3장까지"
        var originalRecords: [Completion] = []
        do {
            let store = try QuestStore(repository: SwiftDataStateRepository(url: url))
            let quest = try #require(store.engine.state.quests.first)
            #expect(quest.notes == nil)
            #expect(quest.name == "기존 독서")
            #expect(store.engine.totals == StatPoints(knowledge: 2))
            originalRecords = store.engine.state.completions
            try store.transact {
                try $0.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: quest.cadence, target: 1, rewards: quest.rewards, at: Date(timeIntervalSinceReferenceDate: 7200), notes: notes)
            }
        }
        let reopened = try QuestStore(repository: SwiftDataStateRepository(url: url))
        #expect(reopened.engine.state.quests.first?.notes == notes)
        #expect(reopened.engine.state.completions == originalRecords)
        #expect(reopened.engine.totals == StatPoints(knowledge: 2))
        #expect(reopened.engine.state.timeZoneID == "Asia/Seoul")
    }
}
