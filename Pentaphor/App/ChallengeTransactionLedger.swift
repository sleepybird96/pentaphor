import Foundation

/// Presentation deduplication only: never consulted to grant purchased access.
@MainActor final class ChallengeTransactionLedger {
    private let defaults: UserDefaults
    private let key = "challenge.presentedTransactions.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func markHandled(_ id: UInt64) -> Bool {
        var handled = defaults.stringArray(forKey: key) ?? []
        guard !handled.contains(String(id)) else { return false }
        handled.append(String(id)); defaults.set(handled, forKey: key)
        return true
    }
}
