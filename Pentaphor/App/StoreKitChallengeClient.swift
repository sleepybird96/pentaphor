import Foundation
import StoreKit
import PentaphorCore

@MainActor final class StoreKitChallengeClient: ChallengeStoreClient {
    private var product: Product?
    private var transactions: [UInt64: Transaction] = [:]
    nonisolated(unsafe) private var listener: Task<Void, Never>?
    nonisolated(unsafe) private var continuation: AsyncStream<ChallengeTransaction>.Continuation?
    lazy var updates: AsyncStream<ChallengeTransaction> = {
        let pair = AsyncStream<ChallengeTransaction>.makeStream()
        continuation = pair.continuation
        listener = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == ChallengePurchaseService.productID else { continue }
                self?.transactions[transaction.id] = transaction
                self?.continuation?.yield(Self.record(transaction))
            }
        }
        return pair.stream
    }()
    deinit { listener?.cancel(); continuation?.finish() }
    func loadProduct() async throws -> ChallengeProduct {
        guard let value = try await Product.products(for: [ChallengePurchaseService.productID]).first,
              value.type == .nonConsumable else { throw StoreError.missingProduct }
        product = value
        return .init(id: value.id, displayPrice: value.displayPrice)
    }
    func currentEntitlement() async throws -> ChallengeAccess {
        var unverified = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let value):
                if value.productID == ChallengePurchaseService.productID && value.revocationDate == nil { return .unlocked }
            case .unverified(let value, _):
                if value.productID == ChallengePurchaseService.productID { unverified = true }
            }
        }
        if unverified { throw StoreError.unverified }
        return .free
    }
    func purchase() async throws -> ChallengePurchaseOutcome {
        if product == nil { _ = try await loadProduct() }
        guard let product else { throw StoreError.missingProduct }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result else { throw StoreError.unverified }
            transactions[transaction.id] = transaction
            return .verified(Self.record(transaction))
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw StoreError.unverified
        }
    }
    func sync() async throws { try await AppStore.sync() }
    func finish(transactionID: UInt64) async {
        guard let transaction = transactions[transactionID] else { return }
        await transaction.finish(); transactions.removeValue(forKey: transactionID)
    }
    private static func record(_ value: Transaction) -> ChallengeTransaction {
        .init(id: value.id, productID: value.productID, isRevoked: value.revocationDate != nil)
    }
    enum StoreError: Error { case missingProduct, unverified }
}
