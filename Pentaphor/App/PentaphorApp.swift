import SwiftUI
import PentaphorCore

@main
struct PentaphorApp: App {
    var body: some Scene {
        WindowGroup {
            AppEntryView().tint(Palette.teal).preferredColorScheme(.light)
        }
    }
}

private struct AppEntryView: View {
    @State private var store: QuestStore?
    @State private var loadError: String?
    @State private var gate = LaunchGate()
    @State private var loadAttempt = 0

    var body: some View {
        Group {
            if !gate.isFinished {
                LaunchLoadingView {
                    withAnimation(.easeOut(duration: 0.18)) { gate.completeCycle() }
                    return gate.isFinished
                }.transition(.opacity)
            } else if let store {
                QuestHome(store: store)
            } else if let loadError {
                ContentUnavailableView {
                    Label("기록을 열지 못했어", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(loadError + "\n기존 기록은 그대로 보관했어.")
                } actions: {
                    Button("다시 시도") {
                        gate = LaunchGate()
                        self.loadError = nil
                        Task { await load() }
                    }.accessibilityIdentifier("launch.retry")
                }
            }
        }
        .background((gate.isFinished ? Palette.paper : Palette.ink).ignoresSafeArea())
        .statusBarHidden(!gate.isFinished)
        .task { if loadAttempt == 0 { await load() } }
    }

    @MainActor private func load() async {
        loadAttempt += 1
        do {
            let repository: SwiftDataStateRepository
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                if ProcessInfo.processInfo.arguments.contains("--ui-test-load-failure"), loadAttempt == 1 {
                    throw CocoaError(.fileReadCorruptFile)
                }
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
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
               ProcessInfo.processInfo.arguments.contains("--ui-test-slow-load") {
                try await Task.sleep(for: .seconds(6))
            }
            #endif
            loadError = nil
            gate.resolveLoad()
        } catch is CancellationError {
            return
        } catch {
            loadError = error.localizedDescription
            gate.resolveLoad()
        }
    }
}
