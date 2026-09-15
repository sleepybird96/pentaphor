import UIKit
import PentaphorCore

@MainActor
final class QuestCompletionAction {
    private let feedback: UINotificationFeedbackGenerator

    init(feedback: UINotificationFeedbackGenerator = UINotificationFeedbackGenerator()) {
        self.feedback = feedback
    }

    func perform(store: QuestStore, questID: UUID, at date: Date, previousWeek: Bool = false) throws -> CompletionResult {
        let hapticsEnabled = store.engine.preferences.hapticsEnabled
        if hapticsEnabled { feedback.prepare() }
        let result = try store.transact { try $0.complete(questID: questID, at: date, previousWeek: previousWeek) }
        // Request feedback after persistence, before presenting the celebration.
        // A newly mounted animation view must not own the completion event.
        if hapticsEnabled { feedback.notificationOccurred(.success) }
        return result
    }
}
