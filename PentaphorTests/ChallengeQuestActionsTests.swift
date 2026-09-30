import XCTest
import PentaphorCore
@testable import Pentaphor

@MainActor final class ChallengeQuestActionsTests: XCTestCase {
    func testCapacityRecheckedAndExistingDataPreserved() async throws {
        let store = try QuestStore(repository: SwiftDataStateRepository(inMemory: true))
        let client = ChallengeClientDouble()
        let service = ChallengePurchaseService(client: client)
        await service.refresh()
        let actions = ChallengeQuestActions(store: store, purchases: service)
        for n in 0..<8 {
            try actions.create { engine in _ = try engine.create(name: "Q\(n)", artID: "climbing", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: Date()) }
        }
        XCTAssertThrowsError(try actions.create { _ in XCTFail("Must not execute mutation") })
        XCTAssertEqual(store.engine.activeQuests.count, 8)
        client.access = .unlocked; await service.refresh()
        try actions.create { engine in _ = try engine.create(name: "Ninth", artID: "climbing", cadence: .week, target: 3, rewards: .zero, at: Date()) }
        client.access = .free; await service.refresh()
        XCTAssertEqual(store.engine.activeQuests.count, 9)
        let first = store.engine.activeQuests[0]
        try store.transact { try $0.setArchived(id: first.id, archived: true) }
        XCTAssertThrowsError(try actions.unarchive(questID: first.id))
        XCTAssertEqual(store.engine.activeQuests.count, 8)
        _ = try store.transact { try $0.complete(questID: store.engine.activeQuests[0].id, at: Date()) }
        XCTAssertEqual(store.engine.totals.stamina, 2)
    }
    func testCheckingAccessCannotCreateButDoesNotMutateState() throws {
        let store = try QuestStore(repository: SwiftDataStateRepository(inMemory: true))
        let service = ChallengePurchaseService(client: ChallengeClientDouble())
        XCTAssertThrowsError(try ChallengeQuestActions(store: store, purchases: service).create { _ in XCTFail() })
        XCTAssertTrue(store.engine.activeQuests.isEmpty)
    }
}
