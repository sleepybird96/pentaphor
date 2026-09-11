import SwiftUI
import PentaphorCore

@main
struct PentaphorApp: App {
    @State private var store: QuestStore?
    @State private var loadError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let store { QuestHome(store: store) }
                else if let loadError {
                    ContentUnavailableView {
                        Label("기록을 열지 못했어", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(loadError + "\n기존 기록은 그대로 보관했어.")
                    } actions: {
                        Button("다시 시도", action: load)
                    }
                } else { ProgressView().task { load() } }
            }
            .tint(Palette.teal)
            .preferredColorScheme(.light)
        }
    }

    @MainActor private func load() {
        do {
            let repository: SwiftDataStateRepository
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                let directory = URL.applicationSupportDirectory.appending(path: "UITestStore", directoryHint: .isDirectory)
                if ProcessInfo.processInfo.arguments.contains("--reset-test-store"), FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                repository = try SwiftDataStateRepository(url: directory.appending(path: "acceptance.store"))
            } else { repository = try SwiftDataStateRepository() }
            #else
            repository = try SwiftDataStateRepository()
            #endif
            store = try QuestStore(repository: repository)
            loadError = nil
        } catch { loadError = error.localizedDescription }
    }
}
