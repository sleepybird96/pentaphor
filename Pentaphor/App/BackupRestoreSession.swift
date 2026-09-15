import Foundation
import Observation
import PentaphorCore

@MainActor @Observable final class BackupRestoreSession {
    private(set) var recoverySnapshot: BackupSnapshot?
    private let recovery: any BackupRecoveryRepository

    init(recovery: any BackupRecoveryRepository) { self.recovery = recovery }

    func refresh() throws {
        recoverySnapshot = nil
        recoverySnapshot = try recovery.load().map { try BackupCodec.read($0) }
    }

    func restore(_ snapshot: BackupSnapshot, into store: QuestStore, at date: Date) throws {
        // The safety slot can change even if saving the restored main state fails.
        // Keep the original restore error while invalidating any stale preview.
        defer { try? refresh() }
        try BackupRestorer.restore(snapshot, into: store, recovery: recovery, at: date)
    }
}
