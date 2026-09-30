#if DEBUG
import Foundation
import PentaphorCore

@MainActor enum ChallengeUITestScenario {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--ui-test-challenge") }
    static func service() -> ChallengePurchaseService {
        let defaults = UserDefaults(suiteName: "ChallengeUITests")!
        if ProcessInfo.processInfo.arguments.contains("--reset-test-store") { defaults.removePersistentDomain(forName: "ChallengeUITests") }
        return ChallengePurchaseService(client: UITestChallengeClient(), ledger: .init(defaults: defaults))
    }
    static func seed(_ store: QuestStore) throws {
        try store.transact { engine in
            let now = Date()
            for i in 0..<8 {
                let q = try engine.create(name: "Quest \(i + 1)", artID: "climbing", cadence: .week, target: 99, rewards: StatPoints(stamina: 2), at: now)
                if i == 0 { for _ in 0..<(ProcessInfo.processInfo.arguments.contains("--ui-test-challenge-small") ? 25 : 70) { _ = try engine.complete(questID: q.id, at: now) } }
            }
            var p = engine.preferences; p.hasCompletedOnboarding = true
            try engine.updatePreferences(p)
        }
    }
}
@MainActor private final class UITestChallengeClient: ChallengeStoreClient {
    var access: ChallengeAccess = .free
    let updates = AsyncStream<ChallengeTransaction> { _ in }
    func loadProduct() async throws -> ChallengeProduct { .init(id: ChallengePurchaseService.productID, displayPrice: "₩5,900") }
    func currentEntitlement() async throws -> ChallengeAccess { access }
    func purchase() async throws -> ChallengePurchaseOutcome {
        access = .unlocked
        return .verified(.init(id: 9001, productID: ChallengePurchaseService.productID, isRevoked: false))
    }
    func sync() async throws {}
    func finish(transactionID: UInt64) async {}
}
#endif
