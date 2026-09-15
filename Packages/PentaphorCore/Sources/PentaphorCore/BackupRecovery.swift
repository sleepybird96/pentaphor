import Darwin
import Foundation

@MainActor public protocol BackupRecoveryRepository {
    func load() throws -> Data?
    func save(_ data: Data) throws
}

/// A single on-device recovery slot, published only after a complete private write.
@MainActor public final class FileBackupRecoveryRepository: BackupRecoveryRepository {
    private let directory: URL
    private var fileURL: URL { directory.appendingPathComponent("pre-restore.pentaphor") }
    public init(directory: URL) { self.directory = directory }

    public func load() throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        // A bounded read also handles a file growing between metadata and read.
        let data = try handle.read(upToCount: BackupCodec.maximumFileSize + 1) ?? Data()
        _ = try BackupCodec.read(data)
        return data
    }
    public func save(_ data: Data) throws {
        _ = try BackupCodec.read(data)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let temporary = directory.appendingPathComponent(".recovery-\(UUID().uuidString).tmp")
        let descriptor = temporary.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600)) }
        guard descriptor >= 0 else { throw posixError() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporary)
        }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()
        let result = temporary.path.withCString { source in
            fileURL.path.withCString { destination in Darwin.rename(source, destination) }
        }
        guard result == 0 else { throw posixError() }
    }
    private func posixError() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
}

@MainActor public enum BackupRestorer {
    public static func restore(_ snapshot: BackupSnapshot, into store: QuestStore, recovery: any BackupRecoveryRepository, at date: Date) throws {
        try AppStateValidator.validate(snapshot.state)
        let safetyCopy = try BackupCodec.make(state: store.engine.state, at: date)
        try recovery.save(safetyCopy)
        try store.replaceState(snapshot.state)
    }
}
