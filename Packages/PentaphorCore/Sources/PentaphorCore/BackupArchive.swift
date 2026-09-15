import CryptoKit
import Foundation

public struct BackupSnapshot: Identifiable, Sendable {
    public let id: String
    public let createdAt: Date
    public let state: AppState
}

public enum BackupError: Error, LocalizedError {
    case oversized, invalidFile, unsupportedApp, unsupportedVersion, checksumMismatch
    public var errorDescription: String? {
        switch self {
        case .oversized: "백업 파일은 20MB 이하여야 합니다."
        case .invalidFile: "백업 파일의 내용이 올바르지 않습니다."
        case .unsupportedApp: "PENTAPHOR에서 만든 백업 파일을 선택해 주세요."
        case .unsupportedVersion: "이 버전의 백업은 아직 읽을 수 없습니다. 앱을 업데이트해 주세요."
        case .checksumMismatch: "백업 파일이 손상되었거나 변경되었습니다. 다른 백업을 선택해 주세요."
        }
    }
}

public enum BackupCodec {
    public static let maximumFileSize = 20 * 1024 * 1024
    private static let appID = "app.pentaphor.personal"
    private struct Envelope: Codable {
        let appID: String
        let formatVersion: Int
        let createdAt: Date
        let payload: Data
        let checksum: String
    }
    public static func make(state: AppState, at date: Date) throws -> Data {
        try AppStateValidator.validate(state)
        guard AppStateValidator.isSupportedDate(date) else { throw BackupError.invalidFile }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(state)
        guard payload.count <= maximumFileSize else { throw BackupError.oversized }
        let data = try encoder.encode(Envelope(appID: appID, formatVersion: 1, createdAt: date, payload: payload, checksum: checksum(payload)))
        guard data.count <= maximumFileSize else { throw BackupError.oversized }
        return data
    }
    public static func read(_ data: Data) throws -> BackupSnapshot {
        guard data.count <= maximumFileSize else { throw BackupError.oversized }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw BackupError.invalidFile }
        guard envelope.appID == appID else { throw BackupError.unsupportedApp }
        guard envelope.formatVersion == 1 else { throw BackupError.unsupportedVersion }
        guard AppStateValidator.isSupportedDate(envelope.createdAt) else { throw BackupError.invalidFile }
        guard checksum(envelope.payload) == envelope.checksum else { throw BackupError.checksumMismatch }
        let state: AppState
        do {
            state = try JSONDecoder().decode(AppState.self, from: envelope.payload)
            try AppStateValidator.validate(state)
        } catch { throw BackupError.invalidFile }
        return BackupSnapshot(id: envelope.checksum, createdAt: envelope.createdAt, state: state)
    }
    private static func checksum(_ payload: Data) -> String {
        SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }
}
