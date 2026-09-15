import XCTest
import UIKit
import PentaphorCore
@testable import Pentaphor

@MainActor
final class QuestCompletionActionTests: XCTestCase {
    private let date = ISO8601DateFormatter().date(from: "2026-09-07T03:00:00Z")!

    func testSuccessRequestsOneHapticOnlyAfterRecordIsPersisted() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let store = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let quest = try makeQuest(store)
        let feedback = FeedbackRecorder()
        feedback.onNotification = { type in
            XCTAssertEqual(type, .success)
            XCTAssertEqual(store.engine.totals.stamina, 2)
            XCTAssertEqual(try repository.load()?.completions.count, 1)
        }
        let action = QuestCompletionAction(feedback: feedback)
        XCTAssertEqual(feedback.notifications.count, 0)
        let result = try action.perform(store: store, questID: quest.id, at: date)
        XCTAssertEqual(result.after.stamina, 2)
        XCTAssertEqual(feedback.notifications, [.success])
        XCTAssertEqual(feedback.preparations, 1)
    }

    func testSavedHapticsPreferenceMutesCompletionAndCanBeReenabled() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let initial = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let quest = try makeQuest(initial)
        try setPreferences(initial, haptics: false)
        let store = try QuestStore(repository: repository)
        let feedback = FeedbackRecorder()
        let action = QuestCompletionAction(feedback: feedback)
        _ = try action.perform(store: store, questID: quest.id, at: date)
        XCTAssertEqual(store.engine.totals.stamina, 2)
        XCTAssertTrue(feedback.notifications.isEmpty)
        XCTAssertEqual(feedback.preparations, 0)
        try setPreferences(store, haptics: true)
        _ = try action.perform(store: store, questID: quest.id, at: date)
        XCTAssertEqual(feedback.notifications, [.success])
        XCTAssertEqual(store.engine.state.completions.count, 2)
    }

    func testFailedPersistenceDoesNotCelebrateOrPublishPoints() throws {
        let repository = FailingRepository()
        let store = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let quest = try makeQuest(store)
        repository.fails = true
        let feedback = FeedbackRecorder()
        let action = QuestCompletionAction(feedback: feedback)
        XCTAssertThrowsError(try action.perform(store: store, questID: quest.id, at: date))
        XCTAssertTrue(feedback.notifications.isEmpty)
        XCTAssertEqual(store.engine.totals, .zero)
        XCTAssertTrue(store.engine.state.completions.isEmpty)
    }

    func testRejectedSecondOneTimeCompletionDoesNotPlayAnotherHaptic() throws {
        let store = try QuestStore(repository: SwiftDataStateRepository(inMemory: true), timeZoneID: "Asia/Seoul")
        let quest = try makeQuest(store, cadence: .once)
        let feedback = FeedbackRecorder()
        let action = QuestCompletionAction(feedback: feedback)
        _ = try action.perform(store: store, questID: quest.id, at: date)
        XCTAssertThrowsError(try action.perform(store: store, questID: quest.id, at: date))
        XCTAssertEqual(feedback.notifications, [.success])
        XCTAssertEqual(store.engine.state.completions.count, 1)
    }

    func testSimplifiedAnimationDoesNotSuppressHaptics() throws {
        let store = try QuestStore(repository: SwiftDataStateRepository(inMemory: true), timeZoneID: "Asia/Seoul")
        let quest = try makeQuest(store)
        try setPreferences(store, haptics: true, simplified: true)
        let feedback = FeedbackRecorder()
        _ = try QuestCompletionAction(feedback: feedback).perform(store: store, questID: quest.id, at: date)
        XCTAssertEqual(feedback.notifications, [.success])
    }

    func testExpiredPreviousWeekRequestDoesNotPlaySuccessHaptic() throws {
        let store = try QuestStore(repository: SwiftDataStateRepository(inMemory: true), timeZoneID: "Asia/Seoul")
        let quest = try makeQuest(store)
        let feedback = FeedbackRecorder()
        let action = QuestCompletionAction(feedback: feedback)
        // September 15, 2026 is Tuesday: the previous-week grace window has closed.
        let tuesday = ISO8601DateFormatter().date(from: "2026-09-15T03:00:00Z")!
        XCTAssertThrowsError(try action.perform(store: store, questID: quest.id, at: tuesday, previousWeek: true))
        XCTAssertTrue(feedback.notifications.isEmpty)
        XCTAssertTrue(store.engine.state.completions.isEmpty)
    }

    private func makeQuest(_ store: QuestStore, cadence: Cadence = .week) throws -> Quest {
        try store.transact { try $0.create(name: "달리기", artID: "running", cadence: cadence, target: 1, rewards: StatPoints(stamina: 2), at: date) }
    }

    private func setPreferences(_ store: QuestStore, haptics: Bool, simplified: Bool = false) throws {
        var preferences = store.engine.preferences
        preferences.hapticsEnabled = haptics
        preferences.simplifiedEffects = simplified
        try store.transact { try $0.updatePreferences(preferences) }
    }
}

@MainActor private final class FeedbackRecorder: UINotificationFeedbackGenerator {
    var preparations = 0
    var notifications: [UINotificationFeedbackGenerator.FeedbackType] = []
    var onNotification: ((UINotificationFeedbackGenerator.FeedbackType) throws -> Void)?
    override func prepare() { preparations += 1 }
    override func notificationOccurred(_ notificationType: UINotificationFeedbackGenerator.FeedbackType) {
        notifications.append(notificationType)
        do { try onNotification?(notificationType) }
        catch { XCTFail("Persisted completion could not be read: \(error)") }
    }
}

@MainActor private final class FailingRepository: StateRepository {
    var fails = false
    var state: AppState?
    func load() throws -> AppState? { state }
    func save(_ state: AppState) throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        self.state = state
    }
}
