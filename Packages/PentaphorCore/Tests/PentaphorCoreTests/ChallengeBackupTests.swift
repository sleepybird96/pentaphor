import XCTest
@testable import PentaphorCore
final class ChallengeBackupTests: XCTestCase {
    func testBackupPreservesExcessGrowthAndQuestCount() throws {
        var engine = QuestEngine(state: AppState(timeZoneID: "Asia/Seoul"))
        let now = Date()
        for i in 0..<12 {
            let quest = try engine.create(name: "Quest \(i)", artID: "climbing", cadence: .week, target: 99, rewards: StatPoints(stamina: 2), at: now)
            if i == 0 { for _ in 0..<60 { _ = try engine.complete(questID: quest.id, at: now) } }
        }
        let restored = QuestEngine(state: try BackupCodec.read(BackupCodec.make(state: engine.state, at: now)).state)
        XCTAssertEqual(restored.activeQuests.count, 12)
        XCTAssertEqual(restored.totals.stamina, 120)
        XCTAssertEqual(ChallengePolicy.displayed(restored.totals, access: .free).stamina, 99)
        XCTAssertEqual(ChallengePolicy.displayed(restored.totals, access: .unlocked).stamina, 120)
    }
}
