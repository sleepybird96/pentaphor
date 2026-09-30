import SwiftUI
import PentaphorCore

@main
struct PentaphorApp: App {
    @State private var reminders = QuestReminderService()
    @State private var purchases: ChallengePurchaseService = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return ChallengeUITestScenario.service() }
        #endif
        return ChallengePurchaseService(client: StoreKitChallengeClient())
    }()
    var body: some Scene {
        WindowGroup {
            AppEntryView().environment(purchases).task { purchases.start() }.environment(reminders).tint(Palette.teal).preferredColorScheme(.light)
        }
    }
}

private struct AppEntryView: View {
    @Environment(ChallengePurchaseService.self) private var purchases
    @Environment(QuestReminderService.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: QuestStore?
    @State private var loadError: String?
    @State private var gate = LaunchGate()
    @State private var loadAttempt = 0
    @State private var recapDateOverride: Date?

    var body: some View {
        Group {
            if !gate.isFinished {
                LaunchLoadingView {
                    withAnimation(.easeOut(duration: 0.18)) { gate.completeCycle() }
                    return gate.isFinished
                }.transition(.opacity)
            } else if let store {
                QuestHome(store: store, recapNow: { recapDateOverride ?? Date() })
            } else if let loadError {
                ContentUnavailableView {
                    Label(AppLocalization.string("PentaphorApp.1"), systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(loadError + AppLocalization.string("PentaphorApp.2"))
                } actions: {
                    Button(AppLocalization.string("PentaphorApp.3")) {
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
        .task(id: store?.engine.state) { await synchronizeReminders() }
        .task(id: scenePhase) { if scenePhase == .active { await purchases.refresh(); await synchronizeReminders() } }
        .onChange(of: scenePhase) { _, phase in
            #if DEBUG
            if phase == .background, WeeklyRecapUITestScenario.enabled, WeeklyRecapUITestScenario.foregroundScenario {
                recapDateOverride = WeeklyRecapUITestScenario.cutoff
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            Task { await synchronizeReminders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await synchronizeReminders() }
        }
    }

    @MainActor private func synchronizeReminders() async {
        if let state = store?.engine.state { await reminders.synchronize(state: state) }
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
            #if DEBUG
            store = try QuestStore(repository: repository, timeZoneID: WeeklyRecapUITestScenario.enabled ? "Asia/Seoul" : TimeZone.current.identifier)
            #else
            store = try QuestStore(repository: repository)
            #endif
            #if DEBUG
            if ChallengeUITestScenario.enabled, let store, ProcessInfo.processInfo.arguments.contains("--reset-test-store") { try ChallengeUITestScenario.seed(store) }
            if WeeklyRecapUITestScenario.enabled, let store {
                recapDateOverride = WeeklyRecapUITestScenario.initialDate
                if ProcessInfo.processInfo.arguments.contains("--reset-test-store") {
                    try WeeklyRecapUITestScenario.seed(store)
                }
            }
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
