import CryptoKit
import Foundation
import Testing
@testable import PentaphorCore

private func backupFixture() throws -> AppState {
    var engine = emptyEngine()
    let quest = try engine.create(name: "백업 독서", artID: "reading", cadence: .week, target: 2, rewards: StatPoints(knowledge: 2), at: created, notes: "기억할 메모 🌿")
    _ = try engine.complete(questID: quest.id, at: created)
    let void = try engine.complete(questID: quest.id, at: created)
    try engine.undo(completionID: void.completion.id)
    try engine.update(id: quest.id, name: quest.name, artID: quest.artID, cadence: .week, target: 3, rewards: .zero, at: created)
    try engine.setArchived(id: quest.id, archived: true)
    try engine.delete(id: quest.id, at: created)
    var state = engine.state
    state.preferences = ExperiencePreferences()
    state.preferences?.nickname = "나의 이름"
    state.weeklyRecapAcknowledgedThrough = engine.calculator.period(containing: created, cadence: .week).start
    return state
}

// Construct independently signed files so malformed payload tests exercise validation,
// rather than failing early merely because their checksum was not updated.
private func signedBackup(_ state: AppState, appID: String = "app.pentaphor.personal", version: Int = 1, date: Date = created) throws -> Data {
    let payload = try JSONEncoder().encode(state)
    return try JSONSerialization.data(withJSONObject: [
        "appID": appID, "formatVersion": version,
        "createdAt": date.timeIntervalSinceReferenceDate,
        "payload": payload.base64EncodedString(),
        "checksum": SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    ])
}

struct BackupCodecTests {
    @Test func roundTripPreservesAllStateAndMetadata() throws {
        let original = try backupFixture()
        let snapshot = try BackupCodec.read(BackupCodec.make(state: original, at: created))
        #expect(snapshot.state == original)
        #expect(snapshot.createdAt == created)
        #expect(snapshot.id.count == 64)
        #expect(QuestEngine(state: snapshot.state).totals.knowledge == 2)
    }
    @Test func acceptsVersionOneLegacyStateWithMissingOptionalFields() throws {
        var original = try backupFixture()
        original.preferences = nil
        original.weeklyRecapAcknowledgedThrough = nil
        original.quests[0].notes = nil
        original.quests[0].reminder = nil
        original.quests[0].deletedAt = nil
        #expect(try BackupCodec.read(signedBackup(original)).state == original)
    }
    @Test(arguments: ["app", "version", "checksum", "payload", "date", "junk", "oversize"])
    func rejectsInvalidEnvelope(kind: String) throws {
        let valid = try signedBackup(backupFixture())
        var object = try #require(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        switch kind {
        case "app": object["appID"] = "another.app"
        case "version": object["formatVersion"] = 2
        case "checksum": object["checksum"] = String(repeating: "0", count: 64)
        case "payload": object["payload"] = Data("tampered".utf8).base64EncodedString()
        case "date": object["createdAt"] = 1e100
        default: break
        }
        let data = kind == "oversize" ? Data(repeating: 32, count: 20 * 1024 * 1024 + 1)
            : kind == "junk" ? Data("no backup".utf8)
            : try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try BackupCodec.read(data) }
    }
    @Test(arguments: ["reference", "period-order", "period-boundary", "period-cadence", "created-date", "record-date", "target-date", "reward-overflow", "duplicate", "target"])
    func rejectsStructurallyInvalidSignedState(kind: String) throws {
        var state = try backupFixture()
        let record = state.completions[0]
        switch kind {
        case "reference": state.quests = []
        case "period-order", "period-boundary", "period-cadence":
            let period = PeriodWindow(start: record.period.start,
                                      end: kind == "period-order" ? record.period.start : record.period.end.addingTimeInterval(1),
                                      cadence: kind == "period-cadence" ? .month : .week)
            state.completions[0] = Completion(id: record.id, questID: record.questID, recordedAt: record.recordedAt, period: period, target: record.target, rewards: record.rewards, isVoided: false)
        case "record-date":
            state.completions[0] = Completion(id: record.id, questID: record.questID, recordedAt: Date(timeIntervalSinceReferenceDate: 1e100), period: record.period, target: record.target, rewards: record.rewards, isVoided: false)
        case "created-date":
            let q = state.quests[0]
            state.quests[0] = Quest(id: q.id, name: q.name, artID: q.artID, cadence: q.cadence, createdAt: Date(timeIntervalSinceReferenceDate: -1e100), isArchived: q.isArchived, rewards: q.rewards, targetChanges: q.targetChanges)
        case "target-date": state.quests[0].targetChanges = [TargetChange(effectiveFrom: Date(timeIntervalSinceReferenceDate: 1e100), target: 1)]
        case "reward-overflow": state.quests[0].rewards = StatPoints(stamina: Int.max, knowledge: Int.max)
        case "duplicate": state.completions.append(record)
        default: state.quests[0].targetChanges = [TargetChange(effectiveFrom: created, target: 0)]
        }
        #expect(throws: (any Error).self) { try BackupCodec.read(signedBackup(state)) }
        #expect(throws: (any Error).self) { try AppStateValidator.validate(state) }
    }
    @Test func rejectsConflictingTargetsWithinPeriodIncludingVoidedRecords() throws {
        var state = try backupFixture()
        let record = state.completions[0]
        // A voided record still participates in the authoritative target lookup.
        state.completions.insert(Completion(id: UUID(), questID: record.questID, recordedAt: record.recordedAt,
                                            period: record.period, target: 14, rewards: .zero, isVoided: true), at: 0)
        #expect(throws: QuestError.invalidState) { try AppStateValidator.validate(state) }
        #expect(throws: BackupError.invalidFile) { try BackupCodec.read(signedBackup(state)) }
    }
    @Test func acceptsDifferentRewardsAndDifferentPeriodTargets() throws {
        var state = try backupFixture()
        let record = state.completions[0]
        state.completions.append(Completion(id: UUID(), questID: record.questID, recordedAt: record.recordedAt,
                                            period: record.period, target: record.target, rewards: .zero, isVoided: false))
        let nextPeriod = PeriodCalculator(timeZoneID: state.timeZoneID).period(containing: record.period.end, cadence: .week)
        state.completions.append(Completion(id: UUID(), questID: record.questID, recordedAt: nextPeriod.start,
                                            period: nextPeriod, target: 14, rewards: .zero, isVoided: false))
        try AppStateValidator.validate(state)
        #expect(try BackupCodec.read(signedBackup(state)).state == state)
    }
    @Test func refusesExportBeyondSizeLimit() throws {
        var state = try backupFixture()
        state.quests[0].notes = String(repeating: "a", count: 20 * 1024 * 1024)
        #expect(throws: (any Error).self) { try BackupCodec.make(state: state, at: created) }
    }
}

@MainActor private final class BackupTestStorage: StateRepository {
    var persisted: AppState?
    var fails = false
    func load() throws -> AppState? { persisted }
    func save(_ state: AppState) throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        persisted = state
    }
}
@MainActor private final class FailingRecovery: BackupRecoveryRepository {
    func load() throws -> Data? { nil }
    func save(_ data: Data) throws { throw CocoaError(.fileWriteNoPermission) }
}

@MainActor struct BackupRestoreTests {
    @Test func restorePersistsExactlyAndRecoveryCanReverseIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("main.store")
        let repository = try SwiftDataStateRepository(url: url)
        let store = try QuestStore(repository: repository, timeZoneID: "America/New_York")
        let original = store.engine.state
        let imported = try backupFixture()
        let recovery = FileBackupRecoveryRepository(directory: directory.appendingPathComponent("recovery"))
        #expect(try recovery.load() == nil)
        try BackupRestorer.restore(BackupCodec.read(signedBackup(imported)), into: store, recovery: recovery, at: created)
        #expect(store.engine.state == imported)
        #expect(store.replacementGeneration == 1)
        #expect(store.engine.totals.knowledge == 2)
        let reopened = try QuestStore(repository: SwiftDataStateRepository(url: url))
        #expect(reopened.engine.state == imported)
        let saved = try #require(try recovery.load())
        #expect(try BackupCodec.read(saved).state == original)
        try BackupRestorer.restore(BackupCodec.read(saved), into: store, recovery: recovery, at: created)
        #expect(store.engine.state == original)
        #expect(store.replacementGeneration == 2)
        #expect(try BackupCodec.read(#require(try recovery.load())).state == imported)
        let files = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("recovery"), includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        let permissions = try FileManager.default.attributesOfItem(atPath: #require(files.first).path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
    }
    @Test func safetyFailureLeavesMemoryAndPersistedStateUnchanged() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let store = try QuestStore(repository: repository, timeZoneID: "UTC")
        let original = store.engine.state
        #expect(throws: CocoaError.self) {
            try BackupRestorer.restore(BackupCodec.read(signedBackup(backupFixture())), into: store, recovery: FailingRecovery(), at: created)
        }
        #expect(store.engine.state == original)
        #expect(try repository.load() == original)
        #expect(store.replacementGeneration == 0)
    }
    @Test func mainSaveFailureLeavesStateAndSafetyCopyIntact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = BackupTestStorage()
        let store = try QuestStore(repository: repository, timeZoneID: "UTC")
        let original = store.engine.state
        let recovery = FileBackupRecoveryRepository(directory: directory)
        repository.fails = true
        #expect(throws: CocoaError.self) {
            try BackupRestorer.restore(BackupCodec.read(signedBackup(backupFixture())), into: store, recovery: recovery, at: created)
        }
        #expect(store.engine.state == original)
        #expect(repository.persisted == original)
        #expect(store.replacementGeneration == 0)
        #expect(try BackupCodec.read(#require(try recovery.load())).state == original)
    }
    @Test func replaceValidatesBeforeSavingAndOnlyReplacementAdvancesGeneration() throws {
        let repository = BackupTestStorage()
        let store = try QuestStore(repository: repository, timeZoneID: "UTC")
        let original = store.engine.state
        var invalid = original
        invalid.version = 42
        #expect(throws: (any Error).self) { try store.replaceState(invalid) }
        #expect(store.engine.state == original)
        #expect(repository.persisted == original)
        #expect(store.replacementGeneration == 0)
        try store.transact { _ = try $0.create(name: "책", artID: "reading", cadence: .once, target: 1, rewards: .zero, at: created) }
        #expect(store.replacementGeneration == 0)
        try store.replaceState(original)
        #expect(store.engine.state == original)
        #expect(repository.persisted == original)
        #expect(store.replacementGeneration == 1)
    }
}
