import XCTest
@testable import PentaphorCore

final class ChallengePolicyTests: XCTestCase {
    func testCapsEachAxisWithoutChangingRaw() {
        let raw = StatPoints(stamina: 101, knowledge: 30, perseverance: 110, charm: 99, courage: 0)
        let shown = ChallengePolicy.displayed(raw, access: .free)
        XCTAssertEqual(shown, StatPoints(stamina: 99, knowledge: 30, perseverance: 99, charm: 99))
        XCTAssertEqual(shown.total, 327)
        XCTAssertEqual(raw.stamina, 101)
        XCTAssertEqual(ChallengePolicy.displayed(raw, access: .unlocked), raw)
    }
    func testQuotaBoundary() {
        XCTAssertTrue(ChallengePolicy.canAddActiveQuest(count: 7, access: .free))
        XCTAssertFalse(ChallengePolicy.canAddActiveQuest(count: 8, access: .free))
        XCTAssertFalse(ChallengePolicy.canAddActiveQuest(count: 9, access: .free))
        XCTAssertTrue(ChallengePolicy.canAddActiveQuest(count: 100, access: .unlocked))
    }
    func testGrowthCrossingCapAndUndo() {
        for (before, after, start, finish, delta, hidden) in [(98,100,98,99,1,true), (99,101,99,99,0,true), (101,98,99,98,-1,false)] {
            let model = ChallengeGrowthPresentation(before: StatPoints(stamina: before), after: StatPoints(stamina: after), access: .free)
            XCTAssertEqual(model.displayBefore.stamina, start)
            XCTAssertEqual(model.displayAfter.stamina, finish)
            XCTAssertEqual(model.displayDelta.stamina, delta)
            XCTAssertEqual(model.hasHiddenGrowth, hidden)
        }
    }
    func testPerseveranceAndUnlockedGrowth() {
        let before = StatPoints(perseverance: 99)
        let after = StatPoints(perseverance: 101)
        XCTAssertEqual(ChallengeGrowthPresentation(before: before, after: after, access: .free).displayDelta.perseverance, 0)
        let model = ChallengeGrowthPresentation(before: before, after: after, access: .unlocked)
        XCTAssertEqual(model.displayDelta.perseverance, 2)
        XCTAssertFalse(model.hasHiddenGrowth)
    }
}
