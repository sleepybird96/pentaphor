import Foundation
import Observation
import PentaphorCore

@MainActor @Observable final class ChallengeUnlockCoordinator {
    private(set) var presentation: ChallengeUnlockEvent?
    private var pending: [ChallengeUnlockEvent] = []
    private var seen: Set<UInt64> = []
    private var generation: Int?
    func enqueue(event: ChallengeUnlockEvent) {
        guard seen.insert(event.id).inserted else { return }
        pending.append(event)
    }
    func presentIfPossible(store: QuestStore, isBusy: Bool) {
        if let generation, generation != store.replacementGeneration { presentation = nil; self.generation = nil }
        guard !isBusy, presentation == nil, !pending.isEmpty else { return }
        presentation = pending.removeFirst(); generation = store.replacementGeneration
    }
    func finish() { presentation = nil; generation = nil }
}
