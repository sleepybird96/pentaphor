import Foundation

enum CloudBackupEnvironment {
    static var writer: CloudBackupWriter {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            if ProcessInfo.processInfo.arguments.contains("--ui-test-cloud-backup") {
                // Substitute only the cloud container boundary; use real files and import UI.
                return CloudBackupWriter(container: { URL.documentsDirectory.appending(path: "UITestCloud", directoryHint: .isDirectory) })
            }
            return CloudBackupWriter(container: { nil })
        }
        #endif
        return CloudBackupWriter()
    }
}
