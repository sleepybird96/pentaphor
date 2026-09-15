import XCTest
import PentaphorCore
@testable import Pentaphor

@MainActor final class WeeklyRecapCoordinatorTests: XCTestCase {
    private let cutoff = ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z")!

    func testColdLaunchAndForegroundAfterCutoffWaitForExistingPresentation() throws {
        let (store, _) = try fixture()
        let coordinator = WeeklyRecapCoordinator()
        coordinator.requestCheck()
        coordinator.presentIfPossible(engine: store.engine, now: cutoff.addingTimeInterval(-1), isBusy: false)
        XCTAssertNil(coordinator.presentation)
        coordinator.requestCheck() // Foreground activation rechecks after 09:00.
        coordinator.presentIfPossible(engine: store.engine, now: cutoff, isBusy: true)
        XCTAssertNil(coordinator.presentation)
        coordinator.presentIfPossible(engine: store.engine, now: cutoff, isBusy: false)
        XCTAssertEqual(coordinator.presentation?.completionCount, 1)
        XCTAssertEqual(store.engine.totals.total, 2)
    }

    func testAcknowledgementPersistsAndPreventsRepeatedLaunchButReplayWorks() throws {
        let (store, repository) = try fixture()
        let coordinator = WeeklyRecapCoordinator()
        coordinator.requestCheck()
        coordinator.presentIfPossible(engine: store.engine, now: cutoff, isBusy: false)
        let recap = try XCTUnwrap(coordinator.presentation)
        let before = store.engine.state
        try coordinator.finish(store: store, at: cutoff)
        XCTAssertNil(coordinator.presentation)
        XCTAssertEqual(store.engine.state.completions, before.completions)
        XCTAssertEqual(store.engine.totals.total, 2)
        let restarted = try QuestStore(repository: repository)
        let next = WeeklyRecapCoordinator()
        next.requestCheck()
        next.presentIfPossible(engine: restarted.engine, now: cutoff, isBusy: false)
        XCTAssertNil(next.presentation)
        next.show(recap)
        XCTAssertEqual(next.presentation?.id, recap.id)
        try next.finish(store: restarted, at: cutoff)
        XCTAssertEqual(restarted.engine.totals.total, 2)
    }

    func testFailedAcknowledgementKeepsReportAndSavedDataForRetry() throws {
        let (store, repository) = try fixture()
        let coordinator = WeeklyRecapCoordinator()
        coordinator.requestCheck()
        coordinator.presentIfPossible(engine: store.engine, now: cutoff, isBusy: false)
        XCTAssertNotNil(coordinator.presentation)
        let saved = store.engine.state
        repository.failSave = true
        XCTAssertThrowsError(try coordinator.finish(store: store, at: cutoff))
        XCTAssertNotNil(coordinator.presentation)
        XCTAssertEqual(store.engine.state, saved)
        repository.failSave = false
        try coordinator.finish(store: store, at: cutoff)
        XCTAssertNil(coordinator.presentation)
    }

    func testRepeatedChecksNeverReplaceAnOpenRecapOrCreatePoints() throws {
        let (store, _) = try fixture()
        let coordinator = WeeklyRecapCoordinator()
        coordinator.requestCheck()
        coordinator.presentIfPossible(engine: store.engine, now: cutoff, isBusy: false)
        let first = try XCTUnwrap(coordinator.presentation)
        coordinator.requestCheck()
        coordinator.presentIfPossible(engine: store.engine, now: cutoff.addingTimeInterval(604800), isBusy: false)
        XCTAssertEqual(coordinator.presentation?.id, first.id)
        XCTAssertEqual(store.engine.totals.total, 2)
    }

    func testClosingOlderReportRetainsForegroundCheckForNewlyClosedWeek() throws {
        let (store, _) = try fixture()
        let coordinator = WeeklyRecapCoordinator()
        coordinator.show(try XCTUnwrap(WeeklyRecapBuilder.latest(engine: store.engine, now: cutoff)))
        let nextCutoff = cutoff.addingTimeInterval(604800)
        try store.transact { engine in
            _ = try engine.complete(questID: engine.activeQuests[0].id, at: cutoff.addingTimeInterval(3600))
        }
        let totals = store.engine.totals
        coordinator.requestCheck()
        coordinator.presentIfPossible(engine: store.engine, now: nextCutoff, isBusy: false)
        try coordinator.finish(store: store, at: nextCutoff)
        coordinator.presentIfPossible(engine: store.engine, now: nextCutoff, isBusy: false)
        XCTAssertEqual(coordinator.presentation?.period, store.engine.calculator.period(containing: cutoff, cadence: .week))
        XCTAssertEqual(store.engine.totals, totals)
    }

    private func fixture() throws -> (QuestStore, RecapRepository) {
        var engine = QuestEngine(state: AppState(timeZoneID: "Asia/Seoul"))
        let created = ISO8601DateFormatter().date(from: "2026-09-01T03:00:00Z")!
        let done = ISO8601DateFormatter().date(from: "2026-09-08T03:00:00Z")!
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1,
                                      rewards: StatPoints(stamina: 2), at: created)
        _ = try engine.complete(questID: quest.id, at: done)
        let repository = RecapRepository()
        repository.state = engine.state
        return (try QuestStore(repository: repository), repository)
    }
}

@MainActor private final class RecapRepository: StateRepository {
    var state: AppState?
    var failSave = false
    func load() throws -> AppState? { state }
    func save(_ state: AppState) throws {
        if failSave { throw CocoaError(.fileWriteOutOfSpace) }
        self.state = state
    }
}
