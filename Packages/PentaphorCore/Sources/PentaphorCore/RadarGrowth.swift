import Foundation

/// Presentation-only geometry. It never changes earned points.
public enum RadarGrowth {
    public static func fraction(points: Double) -> Double {
        let value = max(0, points)
        return value / (value + 50)
    }

    public static func radii(from: StatPoints, to: StatPoints, progress: Double, emphasizeGrowth: Bool = true) -> [Double] {
        let t = min(1, max(0, progress))
        return Stat.allCases.map { stat in
            let value = Double(from[stat]) + (Double(to[stat]) - Double(from[stat])) * t
            let settledRadius = 0.15 + 0.78 * fraction(points: value)
            let wave = sin(2 * .pi * t)
            let pop = emphasizeGrowth && to[stat] > from[stat] ? 0.16 * wave * wave * (1 - t) : 0
            return min(0.99, settledRadius + pop)
        }
    }
}
