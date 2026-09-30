import XCTest
import PentaphorCore
@testable import Pentaphor

@MainActor final class QuestReminderServiceTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-15T09:00:00Z")!

    func testGlobalOffCancelsAlertsAndRestartRestoresSavedSchedule() async throws {
        let center = TestReminderCenter()
        var (engine, quest) = try configuredEngine()
        let originalQuests = engine.state.quests
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        await service.sendTest()
        XCTAssertFalse(center.requests.isEmpty)
        center.requests["another.feature"] = ScheduledReminderNotification(id: "another.feature", questID: nil, fireDate: now, title: "Other", body: "Other")
        var preferences = engine.preferences
        preferences.remindersEnabled = false
        try engine.updatePreferences(preferences)
        await service.synchronize(state: engine.state)
        await service.sendTest()
        XCTAssertEqual(Set(center.requests.keys), ["another.feature"])
        XCTAssertEqual(service.scheduledCount, 0)
        XCTAssertFalse(service.shouldPresent(identifier: "pentaphor.test", rawQuestID: nil, fireDate: nil))
        let fire = ISO8601DateFormatter().date(from: "2026-09-15T11:00:00Z")!
        XCTAssertFalse(service.shouldPresent(identifier: "pentaphor.quest.\(quest.id.uuidString).\(Int(fire.timeIntervalSince1970))", rawQuestID: quest.id.uuidString, fireDate: fire))
        XCTAssertEqual(engine.state.quests, originalQuests)
        let restarted = QuestReminderService(center: center, now: { self.now })
        await restarted.synchronize(state: engine.state)
        XCTAssertEqual(Set(center.requests.keys), ["another.feature"])
        preferences.remindersEnabled = true
        try engine.updatePreferences(preferences)
        await restarted.synchronize(state: engine.state)
        XCTAssertGreaterThan(restarted.scheduledCount, 0)
        XCTAssertEqual(center.permissionRequests, 0)
    }

    func testCompletionCancelsThisWeekAndKeepsNextWeek() async throws {
        let center = TestReminderCenter()
        let (engine, quest) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        let today = ISO8601DateFormatter().date(from: "2026-09-15T11:00:00Z")!
        let nextWeek = ISO8601DateFormatter().date(from: "2026-09-22T11:00:00Z")!
        XCTAssertTrue(center.requests.values.contains { $0.fireDate == today })
        var completed = engine
        _ = try completed.complete(questID: quest.id, at: now)
        await service.synchronize(state: completed.state)
        XCTAssertFalse(center.requests.values.contains { $0.fireDate == today })
        XCTAssertTrue(center.requests.values.contains { $0.fireDate == nextWeek })
        XCTAssertEqual(service.scheduledCount, center.requests.count)
    }

    func testDeniedPermissionClearsOwnedRequestsWithoutPromptingOrTouchingOthers() async throws {
        let center = TestReminderCenter()
        let (engine, _) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        center.requests["another.feature"] = ScheduledReminderNotification(id: "another.feature", questID: nil, fireDate: now.addingTimeInterval(300), title: "Other", body: "Other")
        center.permission = .denied
        await service.synchronize(state: engine.state)
        XCTAssertEqual(Set(center.requests.keys), ["another.feature"])
        XCTAssertEqual(service.authorization, .denied)
        XCTAssertEqual(service.scheduledCount, 0)
        XCTAssertEqual(center.permissionRequests, 0)
    }

    func testSchedulingFailureIsVisibleAndNextSyncRetries() async throws {
        let center = TestReminderCenter()
        center.failAdds = true
        let (engine, _) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertEqual(service.scheduledCount, 0)
        center.failAdds = false
        await service.synchronize(state: engine.state)
        XCTAssertNil(service.errorMessage)
        XCTAssertGreaterThan(service.scheduledCount, 0)
    }

    func testOverlappingSyncConvergesAfterOlderAddFinishes() async throws {
        let center = TestReminderCenter()
        let entered = expectation(description: "old add entered")
        center.blockNextAdd = true
        center.onBlockedAdd = { entered.fulfill() }
        let (engine, quest) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        let first = Task { await service.synchronize(state: engine.state) }
        await fulfillment(of: [entered], timeout: 3)
        var removed = engine
        try removed.setArchived(id: quest.id, archived: true)
        let second = Task { await service.synchronize(state: removed.state) }
        // Yield to enqueue the newer state while the OS add remains suspended.
        await Task.yield()
        center.releaseBlockedAdd()
        await first.value
        await second.value
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(service.scheduledCount, 0)
    }

    func testExplicitPermissionRequestSchedulesOnlySavedConfiguration() async throws {
        let center = TestReminderCenter()
        center.permission = .notDetermined
        let (engine, _) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(center.permissionRequests, 0)
        await service.requestPermission()
        XCTAssertEqual(center.permissionRequests, 1)
        XCTAssertEqual(service.authorization, .allowed)
        XCTAssertFalse(center.requests.isEmpty)
    }

    func testTestNotificationIsSeparateAndReplacesItself() async throws {
        let center = TestReminderCenter()
        let (engine, _) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        let questRequests = center.requests
        await service.sendTest()
        await service.sendTest()
        XCTAssertEqual(center.requests.count, questRequests.count + 1)
        let test = try XCTUnwrap(center.requests["pentaphor.test"])
        XCTAssertNil(test.questID)
        XCTAssertEqual(test.fireDate, now.addingTimeInterval(5))
        XCTAssertEqual(test.title, "PENTAPHOR")
        for (id, request) in questRequests { XCTAssertEqual(center.requests[id], request) }
    }

    func testForegroundPresentsValidMidnightReminder() async throws {
        let center = TestReminderCenter()
        var (engine, quest) = try configuredEngine()
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [4], hour: 0, minute: 0))
        let fire = ISO8601DateFormatter().date(from: "2026-09-15T15:00:00Z")!
        let service = QuestReminderService(center: center, now: { fire })
        await service.synchronize(state: engine.state)
        let identifier = "pentaphor.quest.\(quest.id.uuidString).\(Int(fire.timeIntervalSince1970))"
        XCTAssertTrue(service.shouldPresent(identifier: identifier, rawQuestID: quest.id.uuidString, fireDate: fire))
    }

    func testSuccessfulTestNotificationPreservesQuestSchedulingFailure() async throws {
        let center = TestReminderCenter()
        center.failQuestAdds = true
        let (engine, _) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now })
        await service.synchronize(state: engine.state)
        XCTAssertNotNil(service.errorMessage)
        await service.sendTest()
        XCTAssertNotNil(center.requests["pentaphor.test"])
        XCTAssertNotNil(service.errorMessage, "A successful test must not hide failed quest scheduling")
        XCTAssertEqual(service.scheduledCount, 0)
        center.failQuestAdds = false
        await service.synchronize(state: engine.state)
        XCTAssertNil(service.errorMessage)
        XCTAssertGreaterThan(service.scheduledCount, 0)
    }

    func testSlowAddDoesNotScheduleSubsequentElapsedRequests() async throws {
        let center = TestReminderCenter()
        let entered = expectation(description: "first add suspended")
        center.blockNextAdd = true
        center.onBlockedAdd = { entered.fulfill() }
        var (engine, quest) = try configuredEngine()
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [3, 4, 5], hour: 20, minute: 0))
        let clock = TestReminderClock(date: now)
        let service = QuestReminderService(center: center, now: { clock.date })
        let synchronize = Task { await service.synchronize(state: engine.state) }
        await fulfillment(of: [entered], timeout: 3)
        let elapsed = ISO8601DateFormatter().date(from: "2026-09-16T11:00:00Z")!
        let future = ISO8601DateFormatter().date(from: "2026-09-17T11:00:00Z")!
        clock.date = elapsed.addingTimeInterval(1)
        center.releaseBlockedAdd()
        await synchronize.value
        XCTAssertFalse(center.requests.values.contains { $0.fireDate == elapsed })
        XCTAssertTrue(center.requests.values.contains { $0.fireDate == future })
    }

    func testRoutingRejectsForeignOrMalformedNotification() {
        let id = UUID()
        XCTAssertEqual(ReminderNotificationRouting.questID(identifier: "pentaphor.quest.\(id.uuidString).123", rawQuestID: id.uuidString), id)
        XCTAssertNil(ReminderNotificationRouting.questID(identifier: "another.feature", rawQuestID: id.uuidString))
        XCTAssertNil(ReminderNotificationRouting.questID(identifier: "pentaphor.quest.\(id.uuidString).123", rawQuestID: "invalid"))
        XCTAssertNil(ReminderNotificationRouting.questID(identifier: "pentaphor.quest.\(UUID().uuidString).123", rawQuestID: id.uuidString))
    }

    func testForegroundRejectsOutdatedScheduleAndCompletedGoal() async throws {
        let center = TestReminderCenter()
        var (engine, quest) = try configuredEngine()
        let fire = ISO8601DateFormatter().date(from: "2026-09-15T11:00:00Z")!
        let requestID = "pentaphor.quest.\(quest.id.uuidString).\(Int(fire.timeIntervalSince1970))"
        let service = QuestReminderService(center: center, now: { fire })
        await service.synchronize(state: engine.state)
        XCTAssertTrue(service.shouldPresent(identifier: requestID, rawQuestID: quest.id.uuidString, fireDate: fire))
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [3], hour: 21, minute: 0))
        await service.synchronize(state: engine.state)
        XCTAssertFalse(service.shouldPresent(identifier: requestID, rawQuestID: quest.id.uuidString, fireDate: fire))
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [3], hour: 20, minute: 0))
        _ = try engine.complete(questID: quest.id, at: fire)
        await service.synchronize(state: engine.state)
        XCTAssertFalse(service.shouldPresent(identifier: requestID, rawQuestID: quest.id.uuidString, fireDate: fire))
        XCTAssertTrue(service.shouldPresent(identifier: "pentaphor.test", rawQuestID: nil, fireDate: nil))
    }

    func testLanguageChangeReplacesContentAndRespectsQuota() async throws {
        let center = TestReminderCenter()
        var language = "ko"
        var (engine, quest) = try configuredEngine()
        let service = QuestReminderService(center: center, now: { self.now }, localization: {
            CoreLocalization.text(preferredLanguages: [language], locale: Locale(identifier: "en_US"))
        })
        await service.synchronize(state: engine.state)
        let original = center.requests
        language = "en"
        await service.synchronize(state: engine.state)
        XCTAssertEqual(Set(original.keys), Set(center.requests.keys))
        for (id, value) in center.requests {
            XCTAssertEqual(value.fireDate, original[id]?.fireDate)
            XCTAssertEqual(value.title, quest.name)
            XCTAssertNotEqual(value.body, original[id]?.body)
        }
        _ = try engine.complete(questID: quest.id, at: now)
        await service.synchronize(state: engine.state)
        let period = engine.progress(for: quest, at: now).period
        XCTAssertFalse(center.requests.values.contains { $0.fireDate < period.end })
    }

    private func configuredEngine() throws -> (QuestEngine, Quest) {
        var engine = QuestEngine(state: AppState(timeZoneID: "Asia/Seoul"))
        let quest = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 1, rewards: .zero, at: now.addingTimeInterval(-86400))
        try engine.updateReminder(id: quest.id, reminder: QuestReminder(weekdays: [3], hour: 20, minute: 0))
        return (engine, quest)
    }
}

@MainActor private final class TestReminderCenter: ReminderNotificationCenter {
    var permission: ReminderAuthorization = .allowed
    var permissionRequests = 0
    var requests: [String: ScheduledReminderNotification] = [:]
    var failAdds = false
    var failQuestAdds = false
    var blockNextAdd = false
    var onBlockedAdd: (() -> Void)?
    private var blocked: CheckedContinuation<Void, Never>?
    func authorization() async -> ReminderAuthorization { permission }
    func requestAuthorization() async throws -> Bool {
        permissionRequests += 1
        permission = .allowed
        return true
    }
    func pending() async -> [ScheduledReminderNotification] { Array(requests.values) }
    func add(_ request: ScheduledReminderNotification) async throws {
        if blockNextAdd {
            blockNextAdd = false
            await withCheckedContinuation { continuation in blocked = continuation; onBlockedAdd?() }
        }
        if failAdds || (failQuestAdds && request.id.hasPrefix("pentaphor.quest.")) { throw CocoaError(.fileWriteUnknown) }
        requests[request.id] = request
    }
    func remove(ids: [String]) { for id in ids { requests.removeValue(forKey: id) } }
    func releaseBlockedAdd() { blocked?.resume(); blocked = nil }
}

@MainActor private final class TestReminderClock {
    var date: Date
    init(date: Date) { self.date = date }
}
