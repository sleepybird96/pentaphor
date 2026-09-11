import Foundation
import Testing
@testable import PentaphorCore

let created = instant("2026-09-07T03:00:00Z")
func emptyEngine() -> QuestEngine { QuestEngine(state: AppState(timeZoneID: "Asia/Seoul")) }

struct QuestEngineTests {
    @Test(arguments: ["missing-art", " reading "])
    func rejectsUnknownArtIdentifiers(artID: String) throws {
        var engine = emptyEngine()
        #expect(throws: QuestError.invalidArt) {
            try engine.create(name: "독서", artID: artID, cadence: .week, target: 1, rewards: .zero, at: created)
        }
        #expect(engine.state.quests.isEmpty)
    }
    @Test(arguments: ["", "   ", String(repeating: "가", count: 41)])
    func rejectsInvalidNamesWithoutMutating(name: String) {
        var engine = emptyEngine()
        #expect(throws: QuestError.invalidName) {
            try engine.create(name: name, artID: "running", cadence: .week, target: 3, rewards: .zero, at: created)
        }
        #expect(engine.state.quests.isEmpty)
    }
    @Test(arguments: [0, 100, -1]) func rejectsInvalidTargets(target: Int) {
        var engine = emptyEngine()
        #expect(throws: QuestError.invalidTarget) {
            try engine.create(name: "달리기", artID: "running", cadence: .week, target: target, rewards: .zero, at: created)
        }
        #expect(engine.state.quests.isEmpty)
    }
    @Test(arguments: [StatPoints(stamina: 3), StatPoints(stamina: -1), StatPoints(stamina: -1, courage: 2)])
    func rejectsInvalidAllocation(rewards: StatPoints) {
        var engine = emptyEngine()
        #expect(throws: QuestError.invalidRewards) {
            try engine.create(name: "달리기", artID: "running", cadence: .week, target: 3, rewards: rewards, at: created)
        }
        #expect(engine.state.quests.isEmpty)
    }
    @Test func requiresArtAndTrimsNameWhileAllowingZeroRewards() throws {
        var engine = emptyEngine()
        #expect(throws: QuestError.invalidArt) {
            try engine.create(name: "독서", artID: " ", cadence: .month, target: 1, rewards: .zero, at: created)
        }
        let quest = try engine.create(name: "  내 페이스대로  ", artID: "reading", cadence: .month, target: 1, rewards: .zero, at: created)
        #expect(quest.name == "내 페이스대로")
        #expect(quest.rewards.total == 0)
        #expect(engine.state.quests.count == 1)
    }
}
