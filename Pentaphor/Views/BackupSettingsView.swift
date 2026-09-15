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
                    Text("쌓아온 기록, 안전하게").font(.title2.bold())
                    Text("퀘스트, 메모, 완료 기록과 설정을 파일 하나로 보관합니다.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                summary(store.engine.state)
                VStack(alignment: .leading, spacing: 10) {
                    PrimaryButton(title: "iCloud에 백업 저장") { export() }
                        .accessibilityIdentifier("backup.export")
                    Text("iCloud Drive → PENTAPHOR에 저장합니다. 버튼을 누를 때만 백업하며, 기록은 자동으로 동기화하지 않습니다.")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                if let cloudFile {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("이번 iCloud 백업").font(.headline)
                        Text(cloudFile.lastPathComponent).font(.caption).textSelection(.enabled)
                            .accessibilityIdentifier("backup.cloud.filename")
                        Text(cloudStatusText).font(.subheadline).foregroundStyle(Palette.teal)
                            .accessibilityIdentifier("backup.cloud.status")
                        if cloudState != .uploaded {
                            Text("업로드 완료를 확인한 다음 앱을 삭제하거나 기기를 변경해 주세요. 네트워크와 iCloud 저장 공간에 따라 시간이 걸릴 수 있습니다.")
                                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                            Button("업로드 상태 새로고침") { Task { await refreshCloudState() } }
                                .font(.subheadline.bold()).frame(minHeight: 44)
                        }
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.teal.opacity(0.07), in: CutCorner())
                }
                Button { openImporter() } label: {
                    Label("백업 파일 불러오기", systemImage: "square.and.arrow.down")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                        .background(Palette.teal.opacity(0.08), in: CutCorner())
                }.buttonStyle(.plain).accessibilityIdentifier("backup.import")
                Text("파일을 먼저 확인한 다음 복원할 수 있습니다. 복원하면 현재 데이터가 백업 내용으로 교체됩니다.")
                    .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                if let recoverySnapshot {
                    Divider()
                    Text("최근 복원 전 기록").font(.headline)
                    Text(recoverySnapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Button { preview = recoverySnapshot } label: {
                        Label("복원 전 기록 확인", systemImage: "arrow.uturn.backward")
                            .font(.subheadline.bold()).frame(minHeight: 44)
                    }.accessibilityIdentifier("backup.recovery")
                    Text("가장 최근 복원 직전의 데이터 한 개를 이 기기에 보관합니다. 앱 삭제나 기기 분실에 대비하려면 백업 파일을 별도로 저장하세요.")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                if busy { ProgressView("백업 처리 중…") }
                if let notice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(Palette.teal)
                        .accessibilityIdentifier("backup.notice")
                }
            }.padding(24)
        }
        .background(Palette.paper).foregroundStyle(Palette.ink)
        .navigationTitle("백업 · 복원").navigationBarTitleDisplayMode(.inline)
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
                        Text("백업 내용 확인").font(.title2.bold()).accessibilityIdentifier("backup.preview")
                        Text(snapshot.createdAt.formatted(date: .long, time: .shortened))
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        summary(snapshot.state, identifier: "backup.preview.summary")
                        Text("현재 퀘스트·기록·설정을 이 백업으로 교체합니다. 현재 데이터는 복원 전에 별도로 보관합니다.")
                            .font(.subheadline).lineSpacing(5)
                        Text("알림 권한은 이 아이폰의 설정을 따릅니다. 파라미터는 복원한 완료 기록으로 다시 계산됩니다.")
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                        PrimaryButton(title: "이 백업으로 복원") { restore(snapshot) }
                            .accessibilityIdentifier("backup.restore")
                    }.padding(24)
                }
                .background(Palette.paper).foregroundStyle(Palette.ink)
                .navigationTitle("복원 확인").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("취소") { preview = nil }.accessibilityIdentifier("backup.cancel") } }
                .modifier(ErrorNotice(error: $error))
            }.tint(Palette.teal)
        }
        .alert("백업을 처리하지 못했습니다", isPresented: Binding(get: { error != nil && preview == nil }, set: { if !$0 { error = nil } })) {
            Button("확인") { error = nil }
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
            Text("퀘스트 \(state.quests.count)개 · 완료 기록 \(state.completions.filter { !$0.isVoided }.count)개")
                .font(.headline).accessibilityIdentifier(identifier)
            Text("쌓인 파라미터 \(engine.totals.total) P").font(.subheadline.bold())
            Text(state.timeZoneID).font(.caption).foregroundStyle(Palette.muted)
            Text("보관·삭제한 퀘스트와 되돌린 기록도 파일에 포함됩니다.")
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
        case .pending: "파일 저장됨 · iCloud 업로드 확인 전"
        case .uploaded: "iCloud 업로드 완료"
        case .failed(let reason): "iCloud 업로드 확인 필요 · " + reason
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
            notice = "백업을 복원했습니다."
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
