import SwiftUI
import UniformTypeIdentifiers
import PentaphorCore

extension UTType {
    static let pentaphorBackup = UTType(exportedAs: "app.pentaphor.backup", conformingTo: .data)
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pentaphorBackup] }
    let data: Data
    init(data: Data) throws {
        _ = try BackupCodec.read(data)
        self.data = data
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalidFile }
        try self.init(data: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum BackupFileReader {
    static func read(_ url: URL) throws -> BackupSnapshot {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<BackupSnapshot, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
            result = Result {
                let values = try readableURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { throw BackupError.invalidFile }
                guard (values.fileSize ?? 0) <= BackupCodec.maximumFileSize else { throw BackupError.oversized }
                let file = try FileHandle(forReadingFrom: readableURL)
                defer { try? file.close() }
                let data = try file.read(upToCount: BackupCodec.maximumFileSize + 1) ?? Data()
                return try BackupCodec.read(data)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw BackupError.invalidFile }
        return try result.get()
    }
}
