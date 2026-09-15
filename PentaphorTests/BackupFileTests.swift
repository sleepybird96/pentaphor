import XCTest
import PentaphorCore
@testable import Pentaphor

final class BackupFileTests: XCTestCase {
    func testImportedFileIsDecodedAndValidatedWithoutModifyingItsContents() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "backup.pentaphor")
        let state = AppState(timeZoneID: "Asia/Seoul")
        let data = try BackupCodec.make(state: state, at: Date())
        try data.write(to: url)
        XCTAssertEqual(try BackupFileReader.read(url).state, state)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testDocumentRejectsCorruptExportDataBeforeShowingExporter() throws {
        XCTAssertThrowsError(try BackupDocument(data: Data("not a backup".utf8)))
    }

    func testReaderRejectsMissingDirectoryAndOversizedFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try BackupFileReader.read(directory.appending(path: "missing.pentaphor")))
        XCTAssertThrowsError(try BackupFileReader.read(directory))
        let huge = directory.appending(path: "large.pentaphor")
        try Data(repeating: 0, count: BackupCodec.maximumFileSize + 1).write(to: huge)
        XCTAssertThrowsError(try BackupFileReader.read(huge))
    }
}
