import Foundation

public enum ChallengeAccess: Equatable, Sendable { case free, unlocked }

/// Presentation and capacity rules only. Earned points and backups remain uncapped.
public enum ChallengePolicy {
    public static func displayed(_ raw: StatPoints, access: ChallengeAccess) -> StatPoints {
        guard access == .free else { return raw }
        var result = raw
        for stat in Stat.allCases { result[stat] = min(raw[stat], 99) }
        return result
    }
    public static func canAddActiveQuest(count: Int, access: ChallengeAccess) -> Bool {
        access == .unlocked || count < 8
    }
}

public struct ChallengeGrowthPresentation: Equatable, Sendable {
    public let displayBefore: StatPoints
    public let displayAfter: StatPoints
    public var displayDelta: StatPoints {
        var delta = StatPoints.zero
        for stat in Stat.allCases { delta[stat] = displayAfter[stat] - displayBefore[stat] }
        return delta
    }
    public let hasHiddenGrowth: Bool
    public init(before: StatPoints, after: StatPoints, access: ChallengeAccess) {
        displayBefore = ChallengePolicy.displayed(before, access: access)
        displayAfter = ChallengePolicy.displayed(after, access: access)
        hasHiddenGrowth = access == .free && Stat.allCases.contains { after[$0] > 99 }
    }
}
