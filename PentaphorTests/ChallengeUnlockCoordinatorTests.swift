import XCTest
import PentaphorCore
@testable import Pentaphor
@MainActor final class ChallengeUnlockCoordinatorTests: XCTestCase {
    func testDefersAndDeduplicatesAndInvalidatesRestoredState() throws {
        let store = try QuestStore(repository: SwiftDataStateRepository(inMemory: true))
        let coordinator = ChallengeUnlockCoordinator()
        let event = ChallengeUnlockEvent(transactionID: 8)
        coordinator.enqueue(event: event)
        coordinator.enqueue(event: event)
        coordinator.presentIfPossible(store: store, isBusy: true)
        XCTAssertNil(coordinator.presentation)
        coordinator.presentIfPossible(store: store, isBusy: false)
        XCTAssertEqual(coordinator.presentation?.id, 8)
        try store.replaceState(store.engine.state)
        coordinator.presentIfPossible(store: store, isBusy: false)
        XCTAssertNil(coordinator.presentation)
        coordinator.enqueue(event: event)
        coordinator.presentIfPossible(store: store, isBusy: false)
        XCTAssertNil(coordinator.presentation)
    }
}
