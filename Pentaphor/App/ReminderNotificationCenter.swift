import Foundation
import UserNotifications

@MainActor final class SystemReminderNotificationCenter: NSObject, ReminderNotificationCenter, UNUserNotificationCenterDelegate {
    private let native = UNUserNotificationCenter.current()
    weak var service: QuestReminderService?

    override init() {
        super.init()
        native.delegate = self
    }

    func authorization() async -> ReminderAuthorization {
        await withCheckedContinuation { continuation in
            native.getNotificationSettings { settings in
                let status: ReminderAuthorization
                switch settings.authorizationStatus {
                case .notDetermined: status = .notDetermined
                case .denied: status = .denied
                case .authorized, .provisional, .ephemeral: status = .allowed
                @unknown default: status = .unknown
                }
                continuation.resume(returning: status)
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await native.requestAuthorization(options: [.alert, .sound])
    }

    func pending() async -> [ScheduledReminderNotification] {
        await withCheckedContinuation { continuation in
            native.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map { request in
                    let info = request.content.userInfo
                    return ScheduledReminderNotification(
                        id: request.identifier,
                        questID: (info["questID"] as? String).flatMap(UUID.init(uuidString:)),
                        fireDate: (info["fireDate"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .distantPast,
                        title: request.content.title, body: request.content.body
                    )
                })
            }
        }
    }

    func add(_ request: ScheduledReminderNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = ["fireDate": request.fireDate.timeIntervalSince1970]
        if let id = request.questID { content.userInfo["questID"] = id.uuidString }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireDate)
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await native.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    func remove(ids: [String]) { native.removePendingNotificationRequests(withIdentifiers: ids) }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let request = notification.request
        let identifier = request.identifier
        let rawID = request.content.userInfo["questID"] as? String
        let date = (request.content.userInfo["fireDate"] as? Double).map(Date.init(timeIntervalSince1970:))
        let present = await service?.shouldPresent(identifier: identifier, rawQuestID: rawID, fireDate: date) ?? false
        return present ? [.banner, .list, .sound] : []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let request = response.notification.request
        let id = ReminderNotificationRouting.questID(identifier: request.identifier, rawQuestID: request.content.userInfo["questID"] as? String)
        if let id { await MainActor.run { self.service?.pendingQuestID = id } }
    }
}
