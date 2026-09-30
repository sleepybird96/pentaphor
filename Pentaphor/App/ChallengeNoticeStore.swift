import Foundation
import PentaphorCore
@MainActor final class ChallengeNoticeStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func newlyReached(before: StatPoints, after: StatPoints) -> [Stat] {
        var seen = Set(defaults.stringArray(forKey: "challenge.capNotices") ?? [])
        let reached = Stat.allCases.filter { before[$0] < 99 && after[$0] >= 99 && !seen.contains($0.rawValue) }
        for stat in reached { seen.insert(stat.rawValue) }
        defaults.set(Array(seen), forKey: "challenge.capNotices")
        return reached
    }
    func claimExistingGrowthNotice(raw: StatPoints) -> Bool {
        guard Stat.allCases.contains(where: { raw[$0] > 99 }), !defaults.bool(forKey: "challenge.existingGrowthNotice") else { return false }
        defaults.set(true, forKey: "challenge.existingGrowthNotice"); return true
    }
}
