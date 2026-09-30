import Foundation
import PentaphorCore

enum ChallengeActionError: LocalizedError {
    case checkingAccess, accessUnavailable, activeQuestLimit
    var errorDescription: String? {
        switch self {
        case .checkingAccess: "구매 내역을 확인하고 있어. 잠시 후 다시 시도해줘."
        case .accessUnavailable: "구매 내역을 확인하지 못했어. 설정에서 다시 확인해줘."
        case .activeQuestLimit: "무료로는 퀘스트 8개를 진행할 수 있어. 보관하거나 CHALLENGE를 해금해줘."
        }
    }
}

@MainActor final class ChallengeQuestActions {
    let store: QuestStore
    let purchases: ChallengePurchaseService
    init(store: QuestStore, purchases: ChallengePurchaseService) { self.store = store; self.purchases = purchases }
    func requireCapacity() throws {
        switch purchases.entitlement {
        case .checking: throw ChallengeActionError.checkingAccess
        case .unavailable: throw ChallengeActionError.accessUnavailable
        case .resolved(let access):
            guard ChallengePolicy.canAddActiveQuest(count: store.engine.activeQuests.count, access: access) else { throw ChallengeActionError.activeQuestLimit }
        }
    }
    func create(_ mutation: (inout QuestEngine) throws -> Void) throws {
        try requireCapacity()
        try store.transact(mutation)
    }
    func unarchive(questID: UUID) throws {
        guard let quest = store.engine.archivedQuests.first(where: { $0.id == questID }) else { return }
        let completedOnce = quest.cadence == .once && store.engine.state.completions.contains { $0.questID == questID && !$0.isVoided }
        if !completedOnce { try requireCapacity() }
        try store.transact { try $0.setArchived(id: questID, archived: false) }
    }
}
