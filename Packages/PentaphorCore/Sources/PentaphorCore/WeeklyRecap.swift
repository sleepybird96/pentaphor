import Foundation

public struct WeeklyRecapActivity: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let artID: String
    public let cadence: Cadence
    public let count: Int

    public init(id: UUID, name: String, artID: String, cadence: Cadence, count: Int) {
        self.id = id; self.name = name; self.artID = artID; self.cadence = cadence; self.count = count
    }
}

public struct WeeklyRecap: Identifiable, Equatable, Sendable {
    public var id: Date { period.start }
    public let period: PeriodWindow
    public let completionCount: Int
    public var questCount: Int { activities.count }
    public let weeklyGoalsAchieved: Int
    public let baseGains: StatPoints
    public let streakBonus: Int
    public let gains: StatPoints
    public let before: StatPoints
    public let after: StatPoints
    public let activities: [WeeklyRecapActivity]

    public init(period: PeriodWindow, completionCount: Int, weeklyGoalsAchieved: Int,
                baseGains: StatPoints, streakBonus: Int, before: StatPoints, activities: [WeeklyRecapActivity]) {
        self.period = period; self.completionCount = completionCount
        self.weeklyGoalsAchieved = weeklyGoalsAchieved; self.baseGains = baseGains
        self.streakBonus = streakBonus; self.before = before; self.activities = activities
        self.gains = baseGains + StatPoints(perseverance: streakBonus)
        self.after = before + gains
    }
}

public enum WeeklyRecapBuilder {
    public static func latestClosedWeek(now: Date, timeZoneID: String) -> PeriodWindow {
        let calculator = PeriodCalculator(timeZoneID: timeZoneID)
        let previous = calculator.previous(to: calculator.period(containing: now, cadence: .week))
        return calculator.canRecordPreviousWeek(at: now) ? calculator.previous(to: previous) : previous
    }

    public static func build(engine: QuestEngine, period: PeriodWindow) -> WeeklyRecap? {
        let calculator = engine.calculator
        guard period.cadence == .week,
              period.start.timeIntervalSinceReferenceDate.isFinite,
              calculator.period(containing: period.start, cadence: .week) == period else { return nil }

        let records = engine.state.completions.filter { !$0.isVoided }
        var matching: [Completion] = []
        var before = StatPoints.zero
        var baseGains = StatPoints.zero
        for record in records {
            let week = record.period.cadence == .week
                ? record.period : calculator.period(containing: record.recordedAt, cadence: .week)
            if week == period {
                matching.append(record)
                baseGains = baseGains + record.rewards
            } else if week.start < period.start {
                before = before + record.rewards
            }
        }
        guard !matching.isEmpty else { return nil }

        let recordsByPeriod = Dictionary(grouping: records) {
            QuestPeriod(questID: $0.questID, period: $0.period)
        }
        var streakBonus = 0
        for bonus in engine.bonuses {
            let awardWeek: PeriodWindow
            if bonus.period.cadence == .week {
                awardWeek = bonus.period
            } else {
                // A monthly bonus is earned at the target-th surviving record, not month start.
                let completions = (recordsByPeriod[QuestPeriod(questID: bonus.questID, period: bonus.period)] ?? [])
                    .sorted(by: completionOrder)
                guard let target = completions.first?.target, target > 0, completions.count >= target else { continue }
                awardWeek = calculator.period(containing: completions[target - 1].recordedAt, cadence: .week)
            }
            if awardWeek == period { streakBonus += 1 }
            else if awardWeek.start < period.start { before.perseverance += 1 }
        }

        let byQuest = Dictionary(grouping: matching, by: \.questID)
        let activities = engine.state.quests.compactMap { quest -> WeeklyRecapActivity? in
            guard let completions = byQuest[quest.id] else { return nil }
            return WeeklyRecapActivity(id: quest.id, name: quest.name, artID: quest.artID,
                                       cadence: quest.cadence, count: completions.count)
        }
        let weeklyGoalsAchieved = byQuest.values.filter { completions in
            guard let first = completions.sorted(by: completionOrder).first,
                  first.period.cadence == .week else { return false }
            return completions.count >= first.target
        }.count
        return WeeklyRecap(period: period, completionCount: matching.count, weeklyGoalsAchieved: weeklyGoalsAchieved,
                           baseGains: baseGains, streakBonus: streakBonus, before: before, activities: activities)
    }

    public static func latest(engine: QuestEngine, now: Date) -> WeeklyRecap? {
        build(engine: engine, period: latestClosedWeek(now: now, timeZoneID: engine.state.timeZoneID))
    }

    public static func pending(engine: QuestEngine, now: Date) -> WeeklyRecap? {
        let period = latestClosedWeek(now: now, timeZoneID: engine.state.timeZoneID)
        if let marker = engine.state.weeklyRecapAcknowledgedThrough, period.start <= marker { return nil }
        return build(engine: engine, period: period)
    }

    private struct QuestPeriod: Hashable {
        let questID: UUID
        let period: PeriodWindow
    }

    private static func completionOrder(_ lhs: Completion, _ rhs: Completion) -> Bool {
        lhs.recordedAt == rhs.recordedAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.recordedAt < rhs.recordedAt
    }
}
