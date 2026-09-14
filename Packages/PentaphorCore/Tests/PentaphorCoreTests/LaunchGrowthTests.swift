import Testing
@testable import PentaphorCore

struct LaunchGrowthTests {
    @Test func quickLoadStillWaitsForACompleteCycle() {
        var gate = LaunchGate()
        gate.resolveLoad()
        #expect(!gate.isFinished)
        gate.completeCycle()
        #expect(gate.isFinished)
    }
    @Test func lateLoadFinishesAtTheNextCycleBoundary() {
        var gate = LaunchGate()
        gate.completeCycle()
        #expect(!gate.isFinished)
        gate.resolveLoad()
        #expect(!gate.isFinished)
        gate.completeCycle()
        #expect(gate.isFinished)
    }
    @Test func completionStaysFinishedAcrossFurtherEvents() {
        var gate = LaunchGate()
        gate.resolveLoad()
        gate.completeCycle()
        gate.completeCycle()
        #expect(gate.isFinished)
    }
    @Test func seededCyclesVisitAllFiveAxesAndStayInsideTheFrame() {
        for seed in UInt64(0)..<32 {
            let cycle = LaunchGrowthCycle(seed: seed)
            #expect(Set(cycle.order) == Set(0..<5))
            #expect(cycle.order.count == 5)
            let initial = cycle.radii(progress: 0)
            let final = cycle.radii(progress: 1)
            #expect(zip(initial, final).allSatisfy { $0 < $1 })
            for tick in 0...100 {
                let radii = cycle.radii(progress: Double(tick) / 100)
                #expect(radii.count == 5)
                #expect(radii.allSatisfy { $0.isFinite && $0 > 0 && $0 < 1 })
            }
        }
    }
    @Test func eachAxisPopsAndSettlesWithoutMovingUnstartedAxes() {
        let cycle = LaunchGrowthCycle(seed: 42)
        let initial = cycle.radii(progress: 0)
        let final = cycle.radii(progress: 1)
        let first = cycle.order[0]
        let last = cycle.order[4]
        let early = cycle.radii(progress: 0.20)
        #expect(early[first] > final[first])
        #expect(early[last] == initial[last])
        for axis in 0..<5 {
            let peak = (0...100).map { cycle.radii(progress: Double($0) / 100)[axis] }.max()!
            #expect(peak > final[axis])
        }
        #expect(cycle.radii(progress: 0.99) == final)
    }
    @Test func nextCycleBeginsAtPreviousSettledShape() {
        let first = LaunchGrowthCycle(seed: 42)
        let next = LaunchGrowthCycle(seed: 100, startingRadii: first.radii(progress: 1))
        #expect(next.radii(progress: 0) == first.radii(progress: 1))
        #expect(LaunchGrowthCycle(seed: 42).radii(progress: 0.5) == first.radii(progress: 0.5))
        #expect(LaunchGrowthCycle(seed: 100).radii(progress: 0.5) != first.radii(progress: 0.5))
    }
}
