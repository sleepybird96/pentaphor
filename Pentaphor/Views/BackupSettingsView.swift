import SwiftUI
import PentaphorCore

struct BackupSettingsView: View {
    let store: QuestStore
    @Environment(\.scenePhase) private var scenePhase
    private let cloud = CloudBackupEnvironment.writer
    @State private var cloudFile: URL?
    @State private var cloudState: CloudBackupUploadState = .pending
    @State private var importerDirectory: URL?
    @State private var showImporter = false
    @State private var preview: BackupSnapshot?
    @State private var restoration = BackupRestoreSession(recovery: FileBackupRecoveryRepository(directory: BackupFileLocations.recoveryDirectory))
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?

    private var recoverySnapshot: BackupSnapshot? { restoration.recoverySnapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(title: "KEEP YOUR PROGRESS")
                    Text(AppLocalization.string("BackupSettingsView.1")).font(.title2.bold())
                    Text(AppLocalization.string("BackupSettingsView.2"))
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                summary(store.engine.state)
                VStack(alignment: .leading, spacing: 10) {
                    PrimaryButton(title: AppLocalization.string("BackupSettingsView.3")) { export() }
                        .accessibilityIdentifier("backup.export")
                    Text(AppLocalization.string("BackupSettingsView.4"))
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                if let cloudFile {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppLocalization.string("BackupSettingsView.5")).font(.headline)
                        Text(cloudFile.lastPathComponent).font(.caption).textSelection(.enabled)
                            .accessibilityIdentifier("backup.cloud.filename")
                        Text(cloudStatusText).font(.subheadline).foregroundStyle(Palette.teal)
                            .accessibilityIdentifier("backup.cloud.status")
                        if cloudState != .uploaded {
                            Text(AppLocalization.string("BackupSettingsView.6"))
                                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                            Button(AppLocalization.string("BackupSettingsView.7")) { Task { await refreshCloudState() } }
                                .font(.subheadline.bold()).frame(minHeight: 44)
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.teal.opacity(0.07), in: CutCorner())
                }
                Button { openImporter() } label: {
                    Label(AppLocalization.string("BackupSettingsView.8"), systemImage: "square.and.arrow.down")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                        .background(Palette.teal.opacity(0.08), in: CutCorner())
                }.buttonStyle(.plain).accessibilityIdentifier("backup.import")
                Text(AppLocalization.string("BackupSettingsView.9"))
                    .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                if let recoverySnapshot {
                    Divider()
                    Text(AppLocalization.string("BackupSettingsView.10")).font(.headline)
                    Text(recoverySnapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Button { preview = recoverySnapshot } label: {
                        Label(AppLocalization.string("BackupSettingsView.11"), systemImage: "arrow.uturn.backward")
                            .font(.subheadline.bold()).frame(minHeight: 44)
                    }.accessibilityIdentifier("backup.recovery")
                    Text(AppLocalization.string("BackupSettingsView.12"))
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                if busy { ProgressView(AppLocalization.string("BackupSettingsView.13")) }
                if let notice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(Palette.teal)
                        .accessibilityIdentifier("backup.notice")
                }
            }.padding(24)
        }
        .background(Palette.paper).foregroundStyle(Palette.ink)
        .navigationTitle(AppLocalization.string("BackupSettingsView.14")).navigationBarTitleDisplayMode(.inline)
        .disabled(busy)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pentaphorBackup]) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure(let failure): handle(failure)
            }
        }
        .fileDialogDefaultDirectory(importerDirectory)
        .sheet(item: $preview) { snapshot in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Eyebrow(title: "RESTORE YOUR PROGRESS")
                        Text(AppLocalization.string("BackupSettingsView.15")).font(.title2.bold()).accessibilityIdentifier("backup.preview")
                        Text(snapshot.createdAt.formatted(date: .long, time: .shortened))
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        summary(snapshot.state, identifier: "backup.preview.summary")
                        Text(AppLocalization.string("BackupSettingsView.16"))
                            .font(.subheadline).lineSpacing(5)
                        Text(AppLocalization.string("BackupSettingsView.17"))
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                        PrimaryButton(title: AppLocalization.string("BackupSettingsView.18")) { restore(snapshot) }
                            .accessibilityIdentifier("backup.restore")
                    }.padding(24)
                }
                .background(Palette.paper).foregroundStyle(Palette.ink)
                .navigationTitle(AppLocalization.string("BackupSettingsView.19")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(AppLocalization.string("BackupSettingsView.20")) { preview = nil }.accessibilityIdentifier("backup.cancel") } }
                .modifier(ErrorNotice(error: $error))
            }.tint(Palette.teal)
        }
        .alert(AppLocalization.string("BackupSettingsView.21"), isPresented: Binding(get: { error != nil && preview == nil }, set: { if !$0 { error = nil } })) {
            Button(AppLocalization.string("BackupSettingsView.22")) { error = nil }
        } message: { Text(error ?? "") }
        .task { loadRecovery() }
        .task(id: cloudFile) {
            guard cloudFile != nil else { return }
            for _ in 0..<30 {
                guard !Task.isCancelled else { return }
                await refreshCloudState()
                guard cloudState == .pending else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshCloudState() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in
            cloudFile = nil
            importerDirectory = nil
            cloudState = .pending
        }
    }

    private func summary(_ state: AppState, identifier: String = "backup.summary") -> some View {
        let engine = QuestEngine(state: state)
        return VStack(alignment: .leading, spacing: 10) {
            Text(AppLocalization.format("BackupSettingsView.23", AppLocalization.argument(state.quests.count), AppLocalization.argument(state.completions.filter { !$0.isVoided }.count)))
                .font(.headline).accessibilityIdentifier(identifier)
            Text(AppLocalization.format("BackupSettingsView.24", AppLocalization.argument(engine.totals.total))).font(.subheadline.bold())
            Text(state.timeZoneID).font(.caption).foregroundStyle(Palette.muted)
            Text(AppLocalization.string("BackupSettingsView.25"))
                .font(.caption).foregroundStyle(Palette.muted)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.teal.opacity(0.07), in: CutCorner())
    }

    private func export() {
        notice = nil
        busy = true
        let state = store.engine.state
        Task {
            defer { busy = false }
            do {
                let file = try await Task.detached { try cloud.save(state, at: Date()) }.value
                cloudState = .pending
                cloudFile = file
            } catch { handle(error) }
        }
    }

    private var cloudStatusText: String {
        switch cloudState {
        case .pending: AppLocalization.string("BackupSettingsView.26")
        case .uploaded: AppLocalization.string("BackupSettingsView.27")
        case .failed(let reason): AppLocalization.string("BackupSettingsView.28") + reason
        }
    }

    private func refreshCloudState() async {
        guard let file = cloudFile else { return }
        do {
            let status = try await Task.detached { try cloud.uploadState(for: file) }.value
            guard cloudFile == file, !Task.isCancelled else { return }
            cloudState = status
        } catch {
            guard cloudFile == file, !Task.isCancelled else { return }
            cloudState = .failed(error.localizedDescription)
        }
    }

    private func openImporter() {
        notice = nil
        busy = true
        Task {
            // Legacy portable backups remain importable even when iCloud is unavailable.
            importerDirectory = await Task.detached { try? cloud.documentsDirectory() }.value
            busy = false
            showImporter = true
        }
    }

    private func importFile(_ url: URL) {
        busy = true
        Task {
            do {
                let snapshot = try await Task.detached { try BackupFileReader.read(url) }.value
                busy = false
                preview = snapshot
            } catch { busy = false; handle(error) }
        }
    }

    private func restore(_ snapshot: BackupSnapshot) {
        do {
            try restoration.restore(snapshot, into: store, at: Date())
            preview = nil
            notice = AppLocalization.string("BackupSettingsView.29")
            loadRecovery()
        } catch { handle(error) }
    }

    private func loadRecovery() {
        do { try restoration.refresh() }
        catch { handle(error) }
    }

    private func handle(_ failure: Error) {
        let value = failure as NSError
        guard !(value.domain == NSCocoaErrorDomain && value.code == NSUserCancelledError) else { return }
        error = failure.localizedDescription
    }
}

enum BackupFileLocations {
    static var recoveryDirectory: URL {
        let support = URL.applicationSupportDirectory
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            return support.appending(path: "UITestStore/BackupRecovery", directoryHint: .isDirectory)
        }
        #endif
        return support.appending(path: "BackupRecovery", directoryHint: .isDirectory)
    }
}
