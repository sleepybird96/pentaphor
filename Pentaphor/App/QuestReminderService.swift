import Foundation
import Observation
import PentaphorCore

enum ReminderAuthorization: Equatable, Sendable { case unknown, notDetermined, denied, allowed }

struct ScheduledReminderNotification: Equatable, Sendable {
    let id: String
    let questID: UUID?
    let fireDate: Date
    let title: String
    let body: String
}

@MainActor protocol ReminderNotificationCenter {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func pending() async -> [ScheduledReminderNotification]
    func add(_ request: ScheduledReminderNotification) async throws
    func remove(ids: [String])
}

enum ReminderNotificationRouting {
    static func questID(identifier: String, rawQuestID: String?) -> UUID? {
        guard let rawQuestID, let id = UUID(uuidString: rawQuestID),
              identifier.hasPrefix("pentaphor.quest.\(id.uuidString).") else { return nil }
        return id
    }
}

@MainActor @Observable final class QuestReminderService {
    private(set) var authorization: ReminderAuthorization = .unknown
    var errorMessage: String? {
        let messages = [permissionError, schedulingError, testError].compactMap { $0 }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
    private var permissionError: String?
    private var schedulingError: String?
    private var testError: String?
    private(set) var scheduledCount = 0
    var pendingQuestID: UUID?
    private let center: any ReminderNotificationCenter
    private let now: () -> Date
    private var lastState: AppState?
    private var queuedState: AppState?
    private var generation = 0
    private var worker: Task<Void, Never>?
    private static let prefix = "pentaphor.quest."
    private var remindersEnabled: Bool { lastState?.preferences?.remindersEnabled ?? true }

    convenience init() {
        let system = SystemReminderNotificationCenter()
        self.init(center: system)
        system.service = self
    }

    init(center: any ReminderNotificationCenter, now: @escaping () -> Date = Date.init) {
        self.center = center
        self.now = now
    }

    func synchronize(state: AppState) async {
        lastState = state
        queuedState = state
        generation += 1
        if let worker { await worker.value; return }
        let task = Task { await self.drain() }
        worker = task
        await task.value
    }

    private func drain() async {
        while let state = queuedState {
            queuedState = nil
            let revision = generation
            await reconcile(state: state, revision: revision)
        }
        worker = nil
    }

    private func reconcile(state: AppState, revision: Int) async {
        authorization = await center.authorization()
        let existing = await center.pending().filter { $0.id.hasPrefix(Self.prefix) }
        guard revision == generation else { return }
        guard authorization == .allowed, QuestEngine(state: state).preferences.remindersEnabled else {
            center.remove(ids: existing.map(\.id) + ["pentaphor.test"])
            scheduledCount = 0
            schedulingError = nil
            return
        }
        let desired = QuestReminderPlanner.plan(engine: QuestEngine(state: state), now: now()).map {
            ScheduledReminderNotification(id: $0.id, questID: $0.questID, fireDate: $0.fireDate, title: $0.title, body: $0.body)
        }
        let wanted = Set(desired.map(\.id))
        center.remove(ids: existing.filter { !wanted.contains($0.id) }.map(\.id))
        let previous = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var failure: String?
        for request in desired {
            guard revision == generation else { return }
            guard request.fireDate > now(), previous[request.id] != request else { continue }
            do { try await center.add(request) }
            catch { failure = "알림을 예약하지 못했습니다. 다시 시도해 주세요.\n" + error.localizedDescription }
        }
        let actual = await center.pending()
        guard revision == generation else { return }
        scheduledCount = actual.filter { $0.id.hasPrefix(Self.prefix) }.count
        schedulingError = failure
    }

    func requestPermission() async {
        authorization = await center.authorization()
        permissionError = nil
        if authorization == .notDetermined {
            do {
                _ = try await center.requestAuthorization()
                authorization = await center.authorization()
            } catch {
                permissionError = "알림 권한을 확인하지 못했습니다.\n" + error.localizedDescription
                return
            }
        }
        if let lastState { await synchronize(state: lastState) }
    }

    func sendTest() async {
        guard remindersEnabled else { return }
        await requestPermission()
        guard authorization == .allowed, remindersEnabled else { return }
        do {
            try await center.add(ScheduledReminderNotification(
                id: "pentaphor.test", questID: nil, fireDate: now().addingTimeInterval(5),
                title: "PENTAPHOR", body: "알림이 잘 도착했습니다. 작은 행동을 쌓아 나를 키우다."
            ))
            if !remindersEnabled { center.remove(ids: ["pentaphor.test"]) }
            testError = nil
        } catch { testError = "테스트 알림을 예약하지 못했습니다.\n" + error.localizedDescription }
    }

    func shouldPresent(identifier: String, rawQuestID: String?, fireDate: Date?) -> Bool {
        guard remindersEnabled else { return false }
        if identifier == "pentaphor.test" { return true }
        guard let id = ReminderNotificationRouting.questID(identifier: identifier, rawQuestID: rawQuestID),
              let lastState, let fireDate else { return false }
        let engine = QuestEngine(state: lastState)
        guard let quest = engine.activeQuests.first(where: { $0.id == id }), quest.reminder != nil else { return false }
        let current = engine.progress(for: quest, at: now())
        let delivered = engine.progress(for: quest, at: fireDate)
        guard !current.achieved, current.period == delivered.period else { return false }
        // One second before midnight belongs to the prior day; include the firing day too.
        return QuestReminderPlanner.plan(engine: engine, now: fireDate.addingTimeInterval(-1), horizonDays: 2)
            .contains { $0.id == identifier && $0.questID == id && $0.fireDate == fireDate }
    }
}
