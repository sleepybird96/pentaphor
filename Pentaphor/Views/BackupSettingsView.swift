import SwiftUI
import PentaphorCore

struct BackupSettingsView: View {
    let store: QuestStore
    @State private var document: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var preview: BackupSnapshot?
    @State private var restoration = BackupRestoreSession(recovery: FileBackupRecoveryRepository(directory: BackupFileLocations.recoveryDirectory))
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?
    @State private var filename = "PENTAPHOR-backup"

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
                    PrimaryButton(title: "백업 파일 저장") { export() }
                        .accessibilityIdentifier("backup.export")
                    Text("저장 위치에서 iCloud Drive나 원하는 폴더를 선택하세요. 이 파일로 다른 기기에서도 복원할 수 있습니다.")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                Button { notice = nil; showImporter = true } label: {
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
                if busy { ProgressView("백업 파일 확인 중…") }
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
        .fileExporter(isPresented: $showExporter, document: document, contentType: .pentaphorBackup, defaultFilename: filename) { result in
            switch result {
            case .success: notice = "백업 파일을 저장했습니다."
            case .failure(let failure): handle(failure)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pentaphorBackup]) { result in
            switch result {
            case .success(let url): importFile(url)
            case .failure(let failure): handle(failure)
            }
        }
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
        do {
            notice = nil
            let date = Date()
            document = try BackupDocument(data: BackupCodec.make(state: store.engine.state, at: date))
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            filename = "PENTAPHOR-" + formatter.string(from: date)
            showExporter = true
        } catch { handle(error) }
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
