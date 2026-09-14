import Foundation

/// Reveals the result only at a completed cycle boundary, even when loading is slow.
public struct LaunchGate: Sendable {
    public private(set) var isFinished = false
    private var isLoadResolved = false
    public init() {}
    public mutating func resolveLoad() { isLoadResolved = true }
    public mutating func completeCycle() {
        if isLoadResolved { isFinished = true }
    }
}

/// Decorative normalized radii, independent of user parameters or persistence.
public struct LaunchGrowthCycle: Sendable {
    public let order: [Int]
    private let initial: [Double]
    private let settled: [Double]

    public init(seed: UInt64, startingRadii: [Double]? = nil) {
        var random = LaunchRandom(state: seed)
        order = Array(0..<5).shuffled(using: &random)
        initial = startingRadii ?? [0.30, 0.36, 0.28, 0.32, 0.38]
        precondition(initial.count == 5 && initial.allSatisfy { $0.isFinite && (0..<1).contains($0) })
        settled = initial.map { radius in
            radius + max(0, 0.82 - radius) * Double.random(in: 0.18...0.30, using: &random)
        }
    }

    public func radii(progress: Double) -> [Double] {
        let time = min(max(progress, 0), 1)
        var radii = initial
        for (position, axis) in order.enumerated() {
            let start = 0.05 + Double(position) * 0.15
            let local = min(max((time - start) / 0.28, 0), 1)
            let eased = local * local * (3 - 2 * local)
            let pulse = local > 0 && local < 1 ? pow(sin(.pi * local), 2) * (1 - settled[axis]) * 0.38 : 0
            radii[axis] = initial[axis] + (settled[axis] - initial[axis]) * eased + pulse
        }
        return radii
    }
}

private struct LaunchRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
