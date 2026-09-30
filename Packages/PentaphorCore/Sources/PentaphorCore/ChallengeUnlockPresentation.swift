import Foundation

public struct ChallengeUnlockPresentation: Sendable {
    public let raw: StatPoints
    public var capped: StatPoints { ChallengePolicy.displayed(raw, access: .free) }
    public init(raw: StatPoints) { self.raw = raw }
    public func numbers(progress: Double) -> StatPoints {
        let t = min(1, max(0, progress))
        var result = capped
        for stat in Stat.allCases {
            result[stat] = t == 1 ? raw[stat] : capped[stat] + Int(Double(raw[stat] - capped[stat]) * t)
        }
        return result
    }
    public func radii(progress: Double, simplified: Bool) -> [Double] {
        if simplified { return RadarGrowth.radii(from: raw, to: raw, progress: 1) }
        let t = min(1, max(0, progress))
        return RadarGrowth.radii(from: capped, to: raw, progress: t).map { min(0.99, $0 + 0.10 * sin(.pi * t)) }
    }
}
