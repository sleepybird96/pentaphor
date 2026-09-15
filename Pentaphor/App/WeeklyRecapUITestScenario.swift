#if DEBUG
import Foundation
import PentaphorCore

/// Inputs for the isolated acceptance-test store; never used for personal records.
enum WeeklyRecapUITestScenario {
    static var enabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--ui-testing") && args.contains("--ui-test-weekly-recap")
    }
    static var foregroundScenario: Bool { ProcessInfo.processInfo.arguments.contains("--ui-test-recap-on-foreground") }
    static var cutoff: Date { ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z")! }
    static var initialDate: Date { foregroundScenario ? cutoff.addingTimeInterval(-60) : cutoff }

    @MainActor static func seed(_ store: QuestStore) throws {
        func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
        try store.transact { engine in
            var preferences = engine.preferences
            preferences.hasCompletedOnboarding = true
            preferences.hasCreatedFirstQuest = true
            try engine.updatePreferences(preferences)
            let run = try engine.create(name: "달리기", artID: "running", cadence: .week, target: 2,
                                        rewards: StatPoints(stamina: 1, courage: 1), at: date("2026-09-01T03:00:00Z"))
            for day in ["02", "03", "08", "10"] {
                _ = try engine.complete(questID: run.id, at: date("2026-09-\(day)T11:00:00Z"))
            }
            let reading = try engine.create(name: "독서", artID: "reading", cadence: .month, target: 4,
                                            rewards: StatPoints(knowledge: 2), at: date("2026-09-01T03:00:00Z"))
            for day in ["09", "11"] {
                _ = try engine.complete(questID: reading.id, at: date("2026-09-\(day)T11:00:00Z"))
            }
            let cleaning = try engine.create(name: "화장실 청소", artID: "bathroom-cleaning", cadence: .once, target: 1,
                                             rewards: StatPoints(charm: 2), at: date("2026-09-01T03:00:00Z"))
            _ = try engine.complete(questID: cleaning.id, at: date("2026-09-12T03:00:00Z"))
            if foregroundScenario {
                // The earlier week's report was already seen; only the week closing at 09:00 is pending.
                let earlierWeek = WeeklyRecapBuilder.latestClosedWeek(now: initialDate, timeZoneID: engine.state.timeZoneID)
                try engine.acknowledgeWeeklyRecap(periodStart: earlierWeek.start, at: initialDate)
            }
        }
    }
}
#endif
