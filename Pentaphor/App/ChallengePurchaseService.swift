import Foundation
import Observation
import PentaphorCore

enum ChallengeEntitlementState: Equatable {
    case checking, resolved(ChallengeAccess), unavailable
    var access: ChallengeAccess? { if case .resolved(let value) = self { value } else { nil } }
}
struct ChallengeProduct: Equatable { let id: String; let displayPrice: String }
struct ChallengeTransaction: Sendable { let id: UInt64; let productID: String; let isRevoked: Bool }
enum ChallengePurchaseOutcome { case verified(ChallengeTransaction), pending, cancelled }
enum ChallengePurchaseState: Equatable { case idle, purchasing, pending, restoring }
struct ChallengeUnlockEvent: Identifiable, Equatable { let transactionID: UInt64; var id: UInt64 { transactionID } }

@MainActor protocol ChallengeStoreClient {
    var updates: AsyncStream<ChallengeTransaction> { get }
    func loadProduct() async throws -> ChallengeProduct
    func currentEntitlement() async throws -> ChallengeAccess
    func purchase() async throws -> ChallengePurchaseOutcome
    func sync() async throws
    func finish(transactionID: UInt64) async
}

@MainActor @Observable final class ChallengePurchaseService {
    static let productID = "app.pentaphor.personal.challenge.lifetime"
    private(set) var entitlement: ChallengeEntitlementState = .checking
    private(set) var product: ChallengeProduct?
    private(set) var purchaseState: ChallengePurchaseState = .idle
    private(set) var lastError: String?
    private(set) var restoreMessage: String?
    private(set) var unlockEvents: [ChallengeUnlockEvent] = []
    private let client: any ChallengeStoreClient
    private let ledger: ChallengeTransactionLedger
    @ObservationIgnored nonisolated(unsafe) private var updateTask: Task<Void, Never>?
    private var revision = 0
    private var restoring = false
    init(client: any ChallengeStoreClient, ledger: ChallengeTransactionLedger = .init()) { self.client = client; self.ledger = ledger }
    deinit { updateTask?.cancel() }
    func start() {
        guard updateTask == nil else { return }
        let updates = client.updates
        updateTask = Task { [weak self] in
            for await transaction in updates { guard !Task.isCancelled else { return }; await self?.receive(transaction) }
        }
        Task { await refresh(); await loadProduct() }
    }
    func loadProduct() async {
        do { product = try await client.loadProduct(); lastError = nil }
        catch { lastError = AppLocalization.string("ChallengePurchaseService.1") }
    }
    func refresh() async {
        let version = revision
        do {
            let access = try await client.currentEntitlement()
            guard revision == version else { return }
            entitlement = .resolved(access)
        } catch {
            if entitlement.access == nil { entitlement = .unavailable }
            lastError = AppLocalization.string("ChallengePurchaseService.2")
        }
    }
    func purchase() async {
        guard purchaseState == .idle, entitlement.access == .free else { return }
        purchaseState = .purchasing; lastError = nil; restoreMessage = nil
        do {
            switch try await client.purchase() {
            case .verified(let transaction): await receive(transaction); purchaseState = .idle
            case .pending: purchaseState = .pending
            case .cancelled: purchaseState = .idle
            }
        } catch { purchaseState = .idle; lastError = AppLocalization.string("ChallengePurchaseService.3") }
    }
    func restore() async {
        guard purchaseState != .purchasing && purchaseState != .restoring else { return }
        purchaseState = .restoring; restoring = true; lastError = nil; restoreMessage = nil
        defer { purchaseState = .idle; restoring = false }
        do {
            try await client.sync()
            let version = revision
            let access = try await client.currentEntitlement()
            if revision == version { revision += 1; entitlement = .resolved(access) }
            restoreMessage = entitlement.access == .unlocked ? AppLocalization.string("ChallengePurchaseService.4") : AppLocalization.string("ChallengePurchaseService.5")
        } catch { lastError = AppLocalization.string("ChallengePurchaseService.6") }
    }
    func receive(_ transaction: ChallengeTransaction) async {
        guard transaction.productID == Self.productID else { return }
        revision += 1
        if purchaseState == .pending { purchaseState = .idle }
        if transaction.isRevoked {
            entitlement = .resolved(.free)
            unlockEvents.removeAll()
            await refresh()
        } else {
            let wasUnlocked = entitlement.access == .unlocked
            entitlement = .resolved(.unlocked)
            let first = ledger.markHandled(transaction.id)
            if first && !wasUnlocked && !restoring { unlockEvents.append(.init(transactionID: transaction.id)) }
        }
        await client.finish(transactionID: transaction.id)
    }
    func consumeUnlock(_ id: UInt64) { unlockEvents.removeAll { $0.id == id } }
}
