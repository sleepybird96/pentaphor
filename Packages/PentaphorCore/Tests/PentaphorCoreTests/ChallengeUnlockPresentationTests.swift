import XCTest
@testable import PentaphorCore
final class ChallengeUnlockPresentationTests: XCTestCase {
    func testUnlockRevealsRawGrowthWithoutInventingPoints() {
        let model = ChallengeUnlockPresentation(raw: StatPoints(stamina: 140, knowledge: 50))
        XCTAssertEqual(model.numbers(progress: 0).stamina, 99)
        XCTAssertEqual(model.numbers(progress: 1).stamina, 140)
        XCTAssertEqual(model.numbers(progress: 0.5).knowledge, 50)
        XCTAssertEqual(model.radii(progress: 1, simplified: false), RadarGrowth.radii(from: model.raw, to: model.raw, progress: 1))
        XCTAssertEqual(model.radii(progress: -1, simplified: false), model.radii(progress: 0, simplified: false))
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            XCTAssertTrue(model.radii(progress: t, simplified: false).allSatisfy { $0.isFinite && (0...0.99).contains($0) })
        }
        XCTAssertEqual(model.radii(progress: 0, simplified: true), model.radii(progress: 1, simplified: true))
    }
    func testBelowCapPulsesWithoutChangingNumbers() {
        let model = ChallengeUnlockPresentation(raw: StatPoints(courage: 50))
        XCTAssertEqual(model.numbers(progress: 0), model.numbers(progress: 1))
        XCTAssertGreaterThan(model.radii(progress: 0.5, simplified: false)[4], model.radii(progress: 1, simplified: false)[4])
    }
}
