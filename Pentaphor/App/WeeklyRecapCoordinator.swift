import Foundation
import Observation
import PentaphorCore

@MainActor @Observable final class WeeklyRecapCoordinator {
    private(set) var presentation: WeeklyRecap?
    private var needsCheck = false

    func requestCheck() { needsCheck = true }

    func presentIfPossible(engine: QuestEngine, now: Date, isBusy: Bool) {
        guard needsCheck, !isBusy, presentation == nil else { return }
        needsCheck = false
        presentation = WeeklyRecapBuilder.pending(engine: engine, now: now)
    }

    func show(_ recap: WeeklyRecap) {
        guard presentation == nil else { return }
        needsCheck = false
        presentation = recap
    }

    func finish(store: QuestStore, at date: Date) throws {
        guard let presentation else { return }
        try store.transact { try $0.acknowledgeWeeklyRecap(periodStart: presentation.period.start, at: date) }
        // Persist before dismissal: a failed save must leave this report retryable.
        self.presentation = nil
        // A foreground request received while this report was open may target a newer week.
    }
}
