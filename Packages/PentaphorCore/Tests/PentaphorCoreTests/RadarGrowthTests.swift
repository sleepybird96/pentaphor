import Testing
@testable import PentaphorCore

struct RadarGrowthTests {
    @Test func curveHasStableReferenceValuesAndKeepsGrowing() {
        #expect(RadarGrowth.fraction(points: -1) == 0)
        #expect(RadarGrowth.fraction(points: 0) == 0)
        #expect(abs(RadarGrowth.fraction(points: 10) - 1.0 / 6) < 0.000001)
        #expect(RadarGrowth.fraction(points: 50) == 0.5)
        #expect(abs(RadarGrowth.fraction(points: 100) - 2.0 / 3) < 0.000001)
        #expect(abs(RadarGrowth.fraction(points: 300) - 6.0 / 7) < 0.000001)
        let values = [0.0, 1, 2, 10, 50, 100, 300, 1_000, 100_000]
        for (a, b) in zip(values, values.dropFirst()) {
            #expect(RadarGrowth.fraction(points: a) < RadarGrowth.fraction(points: b))
        }
        #expect(RadarGrowth.fraction(points: 100_000) < 1)
    }

    @Test func growingHighestStatNeverShrinksOtherAxesOrMovesTheBeforeOutline() {
        let before = StatPoints(stamina: 100, knowledge: 50, perseverance: 10, charm: 5, courage: 1)
        var after = before
        after.stamina += 2
        let old = RadarGrowth.radii(from: before, to: before, progress: 1)
        let start = RadarGrowth.radii(from: before, to: after, progress: 0)
        let end = RadarGrowth.radii(from: before, to: after, progress: 1)
        #expect(old == start)
        #expect(end[0] > old[0])
        #expect(Array(end.dropFirst()) == Array(old.dropFirst()))
        for t in [0.15, 0.25, 0.5, 0.75, 0.9] {
            let animated = RadarGrowth.radii(from: before, to: after, progress: t)
            #expect(Array(animated.dropFirst()) == Array(old.dropFirst()))
        }
    }

    @Test func changedVertexPopsTwiceAndSettlesWithoutAffectingReducedMotion() {
        let before = StatPoints(courage: 300)
        let after = StatPoints(courage: 301)
        let settled = RadarGrowth.radii(from: before, to: after, progress: 1)
        for t in [0.25, 0.75] {
            let pop = RadarGrowth.radii(from: before, to: after, progress: t)
            let quiet = RadarGrowth.radii(from: before, to: after, progress: t, emphasizeGrowth: false)
            #expect(pop[4] > settled[4])
            #expect(quiet[4] <= settled[4])
            #expect(Array(pop.prefix(4)) == Array(settled.prefix(4)))
        }
        #expect(settled == RadarGrowth.radii(from: after, to: after, progress: 1))
        #expect(settled == RadarGrowth.radii(from: before, to: after, progress: 1, emphasizeGrowth: false))
    }

    @Test func largeValuesAndAnimationEndpointsStayInsideTheChart() {
        let before = StatPoints(stamina: Int.max - 2)
        let after = StatPoints(stamina: Int.max)
        for t in [-0.1, 0, 0.25, 0.75, 1, 1.1] {
            let radii = RadarGrowth.radii(from: before, to: after, progress: t)
            #expect(radii.allSatisfy { $0.isFinite && (0...1).contains($0) })
        }
        #expect(RadarGrowth.radii(from: before, to: after, progress: -0.1) == RadarGrowth.radii(from: before, to: after, progress: 0))
        #expect(RadarGrowth.radii(from: before, to: after, progress: 1.1) == RadarGrowth.radii(from: before, to: after, progress: 1))
    }
}
