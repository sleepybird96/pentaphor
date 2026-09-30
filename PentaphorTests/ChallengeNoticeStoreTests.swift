import XCTest
import PentaphorCore
@testable import Pentaphor
@MainActor final class ChallengeNoticeStoreTests: XCTestCase {
    func testFirstCrossingPersistsAndUndoDoesNotRepeat() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let notices = ChallengeNoticeStore(defaults: defaults)
        XCTAssertEqual(notices.newlyReached(before: StatPoints(stamina: 98), after: StatPoints(stamina: 100)), [.stamina])
        XCTAssertTrue(ChallengeNoticeStore(defaults: defaults).newlyReached(before: StatPoints(stamina: 98), after: StatPoints(stamina: 100)).isEmpty)
        XCTAssertEqual(notices.newlyReached(before: .zero, after: StatPoints(courage: 99)), [.courage])
        XCTAssertTrue(notices.claimExistingGrowthNotice(raw: StatPoints(stamina: 120)))
        XCTAssertFalse(notices.claimExistingGrowthNotice(raw: StatPoints(stamina: 120)))
    }
}
