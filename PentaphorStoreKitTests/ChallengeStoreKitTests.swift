import XCTest
import StoreKitTest
import StoreKit
import PentaphorCore
@testable import Pentaphor

@MainActor final class ChallengeStoreKitTests: XCTestCase {
    func testLocalPurchaseRestoreAndRefund() async throws {
        let session = try SKTestSession(configurationFileNamed: "Challenge")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let client = StoreKitChallengeClient()
        let product = try await client.loadProduct()
        XCTAssertEqual(product.id, ChallengePurchaseService.productID)
        let initial = try await client.currentEntitlement()
        XCTAssertEqual(initial, .free)
        let outcome = try await client.purchase()
        guard case .verified(let record) = outcome else { return XCTFail("Expected verified purchase") }
        await client.finish(transactionID: record.id)
        let purchased = try await client.currentEntitlement()
        XCTAssertEqual(purchased, .unlocked)
        let restarted = StoreKitChallengeClient()
        let restored = try await restarted.currentEntitlement()
        XCTAssertEqual(restored, .unlocked)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        let refunded = try await waitForAccess(.free, client: restarted)
        XCTAssertEqual(refunded, .free)
    }
    private func waitForAccess(_ expected: ChallengeAccess, client: StoreKitChallengeClient) async throws -> ChallengeAccess {
        for _ in 0..<50 {
            let value = try await client.currentEntitlement()
            if value == expected { return value }
            try await Task.sleep(for: .milliseconds(100))
        }
        return try await client.currentEntitlement()
    }
    func testAskToBuyApproval() async throws {
        let session = try SKTestSession(configurationFileNamed: "Challenge")
        session.disableDialogs = true; session.clearTransactions(); session.askToBuyEnabled = true
        defer { session.askToBuyEnabled = false; session.clearTransactions() }
        let client = StoreKitChallengeClient()
        let outcome = try await client.purchase()
        guard case .pending = outcome else { return XCTFail("Expected pending purchase") }
        let pending = try await client.currentEntitlement()
        XCTAssertEqual(pending, .free)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        let approved = try await waitForAccess(.unlocked, client: client)
        XCTAssertEqual(approved, .unlocked)
    }
}
