import XCTest
import PentaphorCore
@testable import Pentaphor

final class CloudBackupWriterTests: XCTestCase {
    func testManualSaveWritesValidBackupOnlyInsideResolvedCloudDocumentsWithoutReplacingPreviousFile() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = CloudBackupWriter(container: { root })
        let state = AppState(timeZoneID: "Asia/Seoul")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try writer.save(state, at: date)
        let second = try writer.save(state, at: date)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.deletingLastPathComponent(), root.appending(path: "Documents", directoryHint: .isDirectory))
        XCTAssertEqual(first.pathExtension, "pentaphor")
        XCTAssertEqual(try BackupFileReader.read(first).state, state)
        XCTAssertEqual(try BackupFileReader.read(second).createdAt, date)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appending(path: "Documents").path).count, 2)
    }

    func testUnavailableCloudRejectsSaveAndDirectorySelectionWithoutLocalFallback() throws {
        let writer = CloudBackupWriter(container: { nil })
        XCTAssertThrowsError(try writer.save(AppState(timeZoneID: "Asia/Seoul"), at: Date())) { XCTAssertTrue($0 is CloudBackupError) }
        XCTAssertThrowsError(try writer.documentsDirectory()) { XCTAssertTrue($0 is CloudBackupError) }
    }

    func testOrdinaryLocalFileNeverCountsAsUploadedToCloud() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = CloudBackupWriter(container: { root })
        let file = try writer.save(AppState(timeZoneID: "Asia/Seoul"), at: Date())
        XCTAssertEqual(try writer.uploadState(for: file), .pending)
    }

    func testCloudAccountChangeDoesNotReportPreviousAccountsFileAsUploaded() throws {
        let writer = CloudBackupWriter(container: { nil })
        XCTAssertThrowsError(try writer.uploadState(for: URL(filePath: "/previous-account/Documents/backup.pentaphor")))
        let otherAccount = CloudBackupWriter(container: { URL(filePath: "/different-account") })
        XCTAssertThrowsError(try otherAccount.uploadState(for: URL(filePath: "/previous-account/Documents/backup.pentaphor"))) { XCTAssertTrue($0 is CloudBackupError) }
    }

    func testUploadStatusRequiresExplicitCloudConfirmationAndPrioritizesUploadFailure() {
        XCTAssertEqual(CloudBackupUploadState.resolve(isUbiquitous: true, isUploaded: true, uploadError: nil), .uploaded)
        XCTAssertEqual(CloudBackupUploadState.resolve(isUbiquitous: true, isUploaded: false, uploadError: nil), .pending)
        XCTAssertEqual(CloudBackupUploadState.resolve(isUbiquitous: true, isUploaded: nil, uploadError: nil), .pending)
        XCTAssertEqual(CloudBackupUploadState.resolve(isUbiquitous: nil, isUploaded: true, uploadError: nil), .pending)
        XCTAssertEqual(CloudBackupUploadState.resolve(isUbiquitous: false, isUploaded: true, uploadError: nil), .pending)
        XCTAssertEqual(CloudBackupUploadState.resolve(isUbiquitous: true, isUploaded: true, uploadError: "Storage full"), .failed("Storage full"))
    }

    func testBlockedCloudDirectoryLeavesExistingFileUnchanged() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocked = root.appending(path: "Documents")
        let original = Data("existing file".utf8)
        try original.write(to: blocked)
        let writer = CloudBackupWriter(container: { root })
        XCTAssertThrowsError(try writer.save(AppState(timeZoneID: "Asia/Seoul"), at: Date()))
        XCTAssertEqual(try Data(contentsOf: blocked), original)
    }
}
