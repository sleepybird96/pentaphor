import Foundation

public struct QuestReminder: Codable, Equatable, Sendable {
    public var weekdays: [Int]
    public var hour: Int
    public var minute: Int

    public init(weekdays: [Int], hour: Int, minute: Int) {
        self.weekdays = weekdays
        self.hour = hour
        self.minute = minute
    }

    public var isValid: Bool {
        !weekdays.isEmpty && Set(weekdays).count == weekdays.count
            && weekdays.allSatisfy { (1...7).contains($0) }
            && (0...23).contains(hour) && (0...59).contains(minute)
    }
}

public struct PlannedQuestReminder: Equatable, Sendable, Identifiable {
    public let id: String
    public let questID: UUID
    public let fireDate: Date
    public let title: String
    public let body: String

    public init(id: String, questID: UUID, fireDate: Date, title: String, body: String) {
        self.id = id
        self.questID = questID
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

public enum QuestReminderPlanner {
    public static func plan(engine: QuestEngine, now: Date, horizonDays: Int = 42, limit: Int = 60) -> [PlannedQuestReminder] {
        guard engine.preferences.remindersEnabled, horizonDays > 0, limit > 0, let timeZone = TimeZone(identifier: engine.state.timeZoneID) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let firstDay = calendar.startOfDay(for: now)
        var planned: [PlannedQuestReminder] = []

        for quest in engine.activeQuests {
            guard let reminder = quest.reminder, reminder.isValid else { continue }
            let clock = DateComponents(hour: reminder.hour, minute: reminder.minute, second: 0)
            for offset in 0..<min(horizonDays, 42) {
                guard let candidate = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
                // A midnight DST gap can make firstDay 01:00; later days still begin at midnight.
                let day = calendar.startOfDay(for: candidate)
                guard reminder.weekdays.contains(calendar.component(.weekday, from: day)),
                      let fireDate = calendar.nextDate(
                        after: day.addingTimeInterval(-1), matching: clock,
                        matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward
                      ),
                      calendar.isDate(fireDate, inSameDayAs: day),
                      fireDate > now, fireDate >= quest.createdAt else { continue }
                // Progress belongs to the firing period; recording grace does not move it.
                let progress = engine.progress(for: quest, at: fireDate)
                guard !progress.achieved else { continue }
                let remaining = progress.target - progress.count
                let body: String
                switch quest.cadence {
                case .week: body = "이번 주 목표까지 \(remaining)회 남았어."
                case .month: body = "이번 달 목표까지 \(remaining)회 남았어."
                case .once: body = "작은 한 걸음, 지금 시작해볼까?"
                }
                planned.append(PlannedQuestReminder(
                    id: "pentaphor.quest.\(quest.id.uuidString).\(Int(fireDate.timeIntervalSince1970))",
                    questID: quest.id, fireDate: fireDate, title: quest.name, body: body
                ))
            }
        }
        planned.sort {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            return $0.questID.uuidString < $1.questID.uuidString
        }
        return Array(planned.prefix(min(limit, 60)))
    }
}
