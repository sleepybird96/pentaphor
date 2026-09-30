import Foundation
import PentaphorCore

enum CloudBackupUploadState: Equatable, Sendable {
    case pending, uploaded, failed(String)
    static func resolve(isUbiquitous: Bool?, isUploaded: Bool?, uploadError: String?) -> Self {
        if let uploadError { return .failed(uploadError) }
        return isUbiquitous == true && isUploaded == true ? .uploaded : .pending
    }
}

enum CloudBackupError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        AppLocalization.string("CloudBackupWriter.1")
    }
}

struct CloudBackupWriter: Sendable {
    static let containerIdentifier = "iCloud.app.pentaphor.personal"
    let container: @Sendable () -> URL?

    init(container: @escaping @Sendable () -> URL? = {
        FileManager.default.url(forUbiquityContainerIdentifier: CloudBackupWriter.containerIdentifier)
    }) { self.container = container }

    func documentsDirectory() throws -> URL {
        guard let root = container() else { throw CloudBackupError.unavailable }
        return root.appending(path: "Documents", directoryHint: .isDirectory)
    }

    func save(_ state: AppState, at date: Date) throws -> URL {
        let data = try BackupCodec.make(state: state, at: date)
        let directory = try documentsDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let file = directory.appending(path: "PENTAPHOR-\(formatter.string(from: date))-\(UUID().uuidString).pentaphor")
        var coordinationError: NSError?
        var writeResult: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: file, options: [], error: &coordinationError) { destination in
            writeResult = Result { try data.write(to: destination, options: .atomic) }
        }
        if let coordinationError { throw coordinationError }
        guard let writeResult else { throw CocoaError(.fileWriteUnknown) }
        try writeResult.get()
        return file
    }

    func uploadState(for file: URL) throws -> CloudBackupUploadState {
        // Resolve on every check: an old account's URL must not keep showing success.
        let directory = try documentsDirectory().resolvingSymlinksInPath().standardizedFileURL
        guard file.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == directory else {
            throw CloudBackupError.unavailable
        }
        let fresh = URL(fileURLWithPath: file.path)
        let values = try fresh.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey, .ubiquitousItemUploadingErrorKey])
        return .resolve(isUbiquitous: values.isUbiquitousItem, isUploaded: values.ubiquitousItemIsUploaded,
                        uploadError: values.ubiquitousItemUploadingError?.localizedDescription)
    }
}
