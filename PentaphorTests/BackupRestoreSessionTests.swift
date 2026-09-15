import XCTest
import PentaphorCore
@testable import Pentaphor

@MainActor final class BackupRestoreSessionTests: XCTestCase {
    func testFailedMainSaveRefreshesRecoveryPreviewToActualPreRestoreState() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let recovery = FileBackupRecoveryRepository(directory: directory)
        let old = AppState(timeZoneID: "Asia/Seoul")
        try recovery.save(BackupCodec.make(state: old, at: Date()))
        var current = QuestEngine(state: old)
        try current.create(name: "Current", artID: "running", cadence: .week, target: 7, rewards: .zero, at: Date())
        let repository = FailingRestoreRepository(state: current.state)
        let store = try QuestStore(repository: repository)
        let incoming = try BackupCodec.read(BackupCodec.make(state: AppState(timeZoneID: "America/New_York"), at: Date()))
        let session = BackupRestoreSession(recovery: recovery)
        try session.refresh()
        XCTAssertEqual(session.recoverySnapshot?.state.quests.count, 0)
        repository.failSave = true
        XCTAssertThrowsError(try session.restore(incoming, into: store, at: Date())) { error in
            XCTAssertEqual((error as NSError).code, CocoaError.fileWriteOutOfSpace.rawValue)
        }
        XCTAssertEqual(store.engine.state, current.state)
        XCTAssertEqual(session.recoverySnapshot?.state, current.state)
    }
}

@MainActor private final class FailingRestoreRepository: StateRepository {
    var state: AppState
    var failSave = false
    init(state: AppState) { self.state = state }
    func load() throws -> AppState? { state }
    func save(_ state: AppState) throws {
        if failSave { throw CocoaError(.fileWriteOutOfSpace) }
        self.state = state
    }
}
