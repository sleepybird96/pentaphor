import XCTest
import PentaphorCore
@testable import Pentaphor

@MainActor final class ChallengePurchaseServiceTests: XCTestCase {
    func testVerifiedPurchaseUnlocksOnceAndFinishesDuplicate() async {
        let client = ChallengeClientDouble()
        let service = make(client)
        await service.refresh()
        XCTAssertEqual(service.entitlement, .resolved(.free))
        await service.purchase()
        XCTAssertEqual(service.entitlement, .resolved(.unlocked))
        XCTAssertEqual(service.unlockEvents.count, 1)
        await service.receive(client.transaction)
        XCTAssertEqual(service.unlockEvents.count, 1)
        XCTAssertEqual(client.finished, [1, 1])
    }
    func testWrongProductDoesNotUnlock() async {
        let client = ChallengeClientDouble()
        client.transaction = ChallengeTransaction(id: 2, productID: "other", isRevoked: false)
        let service = make(client)
        await service.refresh()
        await service.purchase()
        XCTAssertEqual(service.entitlement, .resolved(.free))
        XCTAssertTrue(service.unlockEvents.isEmpty)
    }
    func testCancelledAndPendingNeverUnlock() async {
        let client = ChallengeClientDouble()
        let service = make(client)
        await service.refresh()
        client.outcome = .cancelled
        await service.purchase()
        XCTAssertEqual(service.purchaseState, .idle)
        client.outcome = .pending
        await service.purchase()
        XCTAssertEqual(service.purchaseState, .pending)
        XCTAssertEqual(service.entitlement, .resolved(.free))
        XCTAssertTrue(service.unlockEvents.isEmpty)
    }
    func testRefreshFailureRetainsVerifiedAccessAndStartupFailureIsUnknown() async {
        let client = ChallengeClientDouble()
        client.fails = true
        let service = make(client)
        await service.refresh()
        XCTAssertEqual(service.entitlement, .unavailable)
        client.fails = false; client.access = .unlocked
        await service.refresh()
        client.fails = true
        await service.refresh()
        XCTAssertEqual(service.entitlement, .resolved(.unlocked))
    }
    func testRestoreDoesNotCelebrateAndRevocationRelocks() async {
        let client = ChallengeClientDouble()
        client.access = .unlocked
        let service = make(client)
        await service.restore()
        XCTAssertEqual(service.entitlement, .resolved(.unlocked))
        XCTAssertTrue(service.unlockEvents.isEmpty)
        client.access = .free
        await service.receive(ChallengeTransaction(id: 1, productID: ChallengePurchaseService.productID, isRevoked: true))
        XCTAssertEqual(service.entitlement, .resolved(.free))
    }
    func testPendingApprovalAfterRestartAndLedgerSuppressesReplay() async {
        let client = ChallengeClientDouble()
        let ledger = ChallengeTransactionLedger(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let first = ChallengePurchaseService(client: client, ledger: ledger)
        await first.refresh()
        await first.receive(client.transaction)
        XCTAssertEqual(first.unlockEvents.count, 1)
        let restarted = ChallengePurchaseService(client: client, ledger: ledger)
        await restarted.receive(client.transaction)
        XCTAssertEqual(restarted.entitlement, .resolved(.unlocked))
        XCTAssertTrue(restarted.unlockEvents.isEmpty)
    }
    func testPurchaseFailureDoesNotUnlockAndCanRetry() async {
        let client = ChallengeClientDouble()
        let service = make(client)
        await service.refresh()
        client.fails = true
        await service.purchase()
        XCTAssertEqual(service.entitlement, .resolved(.free))
        XCTAssertNotNil(service.lastError)
        client.fails = false
        await service.purchase()
        XCTAssertEqual(service.entitlement, .resolved(.unlocked))
    }
    func testPendingBlocksRepeatPurchaseAndApprovalClearsPending() async {
        let client = ChallengeClientDouble()
        client.outcome = .pending
        let service = make(client)
        await service.refresh()
        await service.purchase()
        await service.purchase()
        XCTAssertEqual(client.purchaseCalls, 1)
        await service.receive(client.transaction)
        XCTAssertEqual(service.purchaseState, .idle)
        XCTAssertEqual(service.entitlement, .resolved(.unlocked))
    }
    func testUnresolvedAccessCannotPurchase() async {
        let client = ChallengeClientDouble()
        let service = make(client)
        await service.purchase()
        XCTAssertEqual(client.purchaseCalls, 0)
        client.fails = true
        await service.refresh()
        client.fails = false
        await service.purchase()
        XCTAssertEqual(client.purchaseCalls, 0)
    }
    func testRestoreCannotOverwriteNewerApproval() async {
        let client = ChallengeClientDouble()
        let service = make(client)
        await service.refresh()
        client.suspendEntitlement = true
        let task = Task { await service.restore() }
        while client.entitlementContinuation == nil { await Task.yield() }
        await service.receive(client.transaction)
        client.entitlementContinuation?.resume(returning: .free)
        await task.value
        XCTAssertEqual(service.entitlement, .resolved(.unlocked))
        XCTAssertEqual(service.restoreMessage, "CHALLENGE 구매를 복원했어.")
        XCTAssertTrue(service.unlockEvents.isEmpty)
    }
    private func make(_ client: ChallengeClientDouble) -> ChallengePurchaseService {
        ChallengePurchaseService(client: client, ledger: ChallengeTransactionLedger(defaults: UserDefaults(suiteName: UUID().uuidString)!))
    }
}

@MainActor final class ChallengeClientDouble: ChallengeStoreClient {
    var access = ChallengeAccess.free
    var fails = false
    var purchaseCalls = 0
    var suspendEntitlement = false
    var entitlementContinuation: CheckedContinuation<ChallengeAccess, Error>?
    var outcome: ChallengePurchaseOutcome?
    var transaction = ChallengeTransaction(id: 1, productID: "app.pentaphor.personal.challenge.lifetime", isRevoked: false)
    var finished: [UInt64] = []
    let updates = AsyncStream<ChallengeTransaction> { _ in }
    func loadProduct() async throws -> ChallengeProduct { if fails { throw CocoaError(.fileReadUnknown) }; return ChallengeProduct(id: transaction.productID, displayPrice: "₩5,900") }
    func currentEntitlement() async throws -> ChallengeAccess {
        if fails { throw CocoaError(.fileReadUnknown) }
        if suspendEntitlement { return try await withCheckedThrowingContinuation { entitlementContinuation = $0 } }
        return access
    }
    func purchase() async throws -> ChallengePurchaseOutcome { purchaseCalls += 1; if fails { throw CocoaError(.fileReadUnknown) }; return outcome ?? .verified(transaction) }
    func sync() async throws { if fails { throw CocoaError(.fileReadUnknown) } }
    func finish(transactionID: UInt64) async { finished.append(transactionID) }
}
