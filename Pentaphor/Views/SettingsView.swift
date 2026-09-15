import SwiftUI
import PentaphorCore

struct SettingsView: View {
    let store: QuestStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(QuestReminderService.self) private var reminderService
    @Environment(\.openURL) private var openURL
    @State private var nickname: String
    @State private var savedNickname = false
    @State private var showIntroduction = false
    @State private var error: String?
    @State private var reminderActionRunning = false
    @State private var testRequested = false
    @FocusState private var editingNickname: Bool

    init(store: QuestStore) {
        self.store = store
        _nickname = State(initialValue: store.engine.preferences.nickname)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(title: BrandCopy.slogan, color: Palette.bright)
                        Text(BrandCopy.tagline).font(.title3.bold())
                    }.padding(21).frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(Palette.paper).background(Palette.ink)
                    nicknameSection
                    VStack(alignment: .leading, spacing: 13) {
                        sectionTitle("화면과 반응")
                        Toggle("햅틱", isOn: preferenceBinding(\.hapticsEnabled)).accessibilityIdentifier("settings.haptics")
                        Text("완료했을 때 짧은 진동으로 알려줘.").font(.caption).foregroundStyle(Palette.muted)
                        Divider()
                        Toggle("달성 연출 간소하게", isOn: preferenceBinding(\.simplifiedEffects)).accessibilityIdentifier("settings.simple-effects")
                        Text(reduceMotion ? "아이폰의 ‘동작 줄이기’가 켜져 있어. 간소한 연출을 적용하고 있어." : "움직이는 연출 대신, 쌓인 결과를 바로 보여줘. 아이폰의 ‘동작 줄이기’도 따라가.")
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                    }
                    reminderSection
                    NavigationLink { BackupSettingsView(store: store) } label: {
                        settingsRow("백업 · 복원", symbol: "externaldrive")
                    }.accessibilityIdentifier("settings.backup")
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle("기록과 사용 안내").padding(.bottom, 9)
                        NavigationLink { GuideDetailView(page: .time, timeZoneID: store.engine.state.timeZoneID) } label: {
                            settingsRow("기록 기준", symbol: "globe.asia.australia", detail: store.engine.state.timeZoneID)
                        }.accessibilityIdentifier("settings.time")
                        Button { editingNickname = false; showIntroduction = true } label: {
                            settingsRow("시작 안내 다시 보기", symbol: "play.rectangle")
                        }.accessibilityIdentifier("settings.replay")
                        NavigationLink { GuideDetailView(page: .rules, timeZoneID: store.engine.state.timeZoneID) } label: {
                            settingsRow("파라미터와 기록 안내", symbol: "pentagon")
                        }.accessibilityIdentifier("settings.rules")
                        NavigationLink { GuideDetailView(page: .about, timeZoneID: store.engine.state.timeZoneID) } label: {
                            settingsRow("앱 정보 · 데이터 안내", symbol: "info.circle")
                        }.accessibilityIdentifier("settings.about")
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.paper).foregroundStyle(Palette.ink)
            .navigationTitle("설정").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() }.accessibilityIdentifier("settings.done") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { editingNickname = false } }
            }
            .fullScreenCover(isPresented: $showIntroduction) {
                IntroductionView(store: store, isReplay: true) { _ in showIntroduction = false }
            }
            .modifier(ErrorNotice(error: $error))
            .task { await reminderService.synchronize(state: store.engine.state) }
            .onChange(of: store.replacementGeneration) { _, _ in
                nickname = store.engine.preferences.nickname
                savedNickname = false
                editingNickname = false
                testRequested = false
            }
        }.tint(Palette.teal)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("알림")
            Toggle("퀘스트 알림", isOn: Binding(
                get: { store.engine.preferences.remindersEnabled && reminderService.authorization == .allowed },
                set: { setRemindersEnabled($0) }
            ))
            .frame(minHeight: 44)
            .disabled(reminderActionRunning || reminderService.authorization == .unknown)
            .accessibilityIdentifier("settings.reminder.enabled")
            Text("정해둔 요일과 시각에 알려줘. 꺼도 퀘스트별 알림 설정은 그대로 보관돼.")
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            HStack {
                Text("아이폰 알림 권한").font(.subheadline)
                Spacer()
                Text(reminderAuthorizationLabel).font(.subheadline.bold()).foregroundStyle(Palette.teal)
                    .accessibilityIdentifier("settings.reminder.authorization")
            }
            switch reminderService.authorization {
            case .denied:
                Text("알림이 꺼져 있어. 퀘스트별 요일과 시각은 보관돼. 아이폰 설정에서 알림을 허용한 뒤 앱으로 돌아와줘.")
                    .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                Button("아이폰 알림 설정 열기") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }.font(.subheadline.bold()).frame(minHeight: 44)
                    .accessibilityIdentifier("settings.reminder.open-settings")
            case .notDetermined:
                Text("토글을 켜면 아이폰 알림 권한을 요청해.")
                    .font(.caption).foregroundStyle(Palette.muted)
            case .allowed:
                if store.engine.preferences.remindersEnabled {
                    Text("예약된 퀘스트 알림 \(reminderService.scheduledCount)개")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("settings.reminder.count")
                    Button("5초 뒤 테스트 알림 받기") {
                        reminderActionRunning = true
                        testRequested = false
                        Task {
                            await reminderService.sendTest()
                            testRequested = reminderService.errorMessage == nil && reminderService.authorization == .allowed
                            reminderActionRunning = false
                        }
                    }.font(.subheadline.bold()).frame(minHeight: 44).disabled(reminderActionRunning)
                        .accessibilityIdentifier("settings.reminder.test")
                    Text(testRequested ? "테스트 알림을 요청했어. 알림이 나타나는 방식은 아이폰 설정을 따라가. 기록과 포인트는 바뀌지 않아." : "실제 아이폰 알림으로 확인해봐. 테스트는 기록과 포인트에 영향을 주지 않아.")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                        .accessibilityIdentifier("settings.reminder.test-status")
                } else {
                    Text("알림을 쉬고 있어. 다시 켜면 저장한 요일과 시각으로 알려줘.")
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
            case .unknown:
                ProgressView("알림 권한 확인 중").font(.caption)
            }
            if let message = reminderService.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red).lineSpacing(4)
                    .accessibilityIdentifier("settings.reminder.error")
                Button("알림 예약 다시 시도") {
                    reminderActionRunning = true
                    Task {
                        await reminderService.synchronize(state: store.engine.state)
                        reminderActionRunning = false
                    }
                }.font(.subheadline.bold()).frame(minHeight: 44).disabled(reminderActionRunning)
                    .accessibilityIdentifier("settings.reminder.retry")
            }
            Text("퀘스트 수정에서 요일과 시각을 골라. 그 주·그 달의 목표를 채우면 해당 기간의 남은 알림은 쉬고, 한 번 퀘스트는 완료하면 멈춰.")
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            Text("알림 시각과 요일은 저장된 기록 시간대(\(store.engine.state.timeZoneID))를 따라가.")
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            Text("앞으로 최대 42일 동안의 알림 중 가까운 60개까지 이 기기에 예약해. 앱을 열거나 기록을 바꿀 때 채워지므로, 오래 열지 않으면 예약된 알림이 끝날 수 있어.")
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                .accessibilityIdentifier("settings.reminder.reservation-notice")
        }
    }

    private func setRemindersEnabled(_ enabled: Bool) {
        do {
            var preferences = store.engine.preferences
            preferences.remindersEnabled = enabled
            try store.transact { try $0.updatePreferences(preferences) }
        } catch {
            self.error = error.localizedDescription
            return
        }
        let wasDenied = reminderService.authorization == .denied
        reminderActionRunning = true
        testRequested = false
        Task {
            if enabled { await reminderService.requestPermission() }
            await reminderService.synchronize(state: store.engine.state)
            reminderActionRunning = false
            // An existing denial needs Settings; a newly declined prompt stays here.
            if enabled, wasDenied, reminderService.authorization == .denied,
               let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                openURL(url)
            }
        }
    }

    private var reminderAuthorizationLabel: String {
        switch reminderService.authorization {
        case .unknown: "확인 중"
        case .notDetermined: "아직 선택하지 않음"
        case .denied: "허용 안 됨"
        case .allowed: "허용됨"
        }
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("나")
            HStack {
                TextField("닉네임 · 선택", text: $nickname)
                    .font(.title3.bold()).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($editingNickname).submitLabel(.done).onSubmit(saveNickname)
                    .accessibilityIdentifier("settings.nickname")
                if !nickname.isEmpty {
                    Button { nickname = ""; savedNickname = false } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                    }.accessibilityLabel("닉네임 비우기").accessibilityIdentifier("settings.nickname.clear")
                }
                Button("저장", action: saveNickname).font(.subheadline.bold()).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("settings.nickname.save")
            }.padding(.leading, 12).background(Palette.ink.opacity(0.045))
            Text(savedNickname ? "저장했어." : "20자 이내 · 비워두면 ‘나의 파라미터’로 표시돼.")
                .font(.caption).foregroundStyle(Palette.muted)
                .accessibilityIdentifier("settings.nickname.status")
        }.onChange(of: nickname) { _, _ in savedNickname = false }
    }

    private func saveNickname() {
        do {
            var preferences = store.engine.preferences
            preferences.nickname = nickname
            try store.transact { try $0.updatePreferences(preferences) }
            nickname = store.engine.preferences.nickname
            editingNickname = false
            savedNickname = true
        } catch { self.error = error.localizedDescription }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<ExperiencePreferences, Bool>) -> Binding<Bool> {
        Binding(get: { store.engine.preferences[keyPath: keyPath] }, set: { value in
            do {
                var preferences = store.engine.preferences
                preferences[keyPath: keyPath] = value
                try store.transact { try $0.updatePreferences(preferences) }
            } catch { self.error = error.localizedDescription }
        })
    }

    private func sectionTitle(_ title: String) -> some View { Text(title).font(.headline) }

    private func settingsRow(_ title: String, symbol: String, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(Palette.teal)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.bold())
                if let detail { Text(detail).font(.caption).foregroundStyle(Palette.muted) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
        }.frame(minHeight: 52).padding(.vertical, 5).contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink.opacity(0.15)).frame(height: 1) }
    }
}

private enum GuidePage { case time, rules, about }

private struct GuideDetailView: View {
    let page: GuidePage
    let timeZoneID: String
    private var title: String {
        switch page { case .time: "기록 기준"; case .rules: "파라미터와 기록 안내"; case .about: "앱 정보" }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                switch page {
                case .time:
                    explanation("한 번 해볼 일", "기한 없이 남겨두고 한 번 완료하면 목록에서 빠져. 기록과 포인트는 남고, 기록을 되돌리면 다시 목록에 나타나. 보관하거나 삭제한 퀘스트는 그대로 유지돼.")
                    explanation("집계 시간대", timeZoneID + "\n처음 시작한 시간대를 유지해. 여행 중에도 주·월 기록의 기준은 바뀌지 않아.")
                    explanation("한 주는 월요일 0시부터", "새 주는 월요일 0시에 시작해. 월요일 오전 9시 전까지는 완료할 때 ‘지난주에 기록’을 선택할 수 있어. 기본은 이번 주 기록이야.")
                    explanation("한 달은 1일 0시부터", "월간 목표는 매월 1일 0시에 새로 시작해. 월간 기록에는 주간과 같은 유예 시간이 없어.")
                case .rules:
                    explanation("다섯 파라미터", "체력 · 지식 · 끈기 · 매력 · 용기\n어떤 행동이 무엇을 키울지는 네가 정해. 한 번 완료할 때 받을 포인트를 최대 2점까지 나눌 수 있어.")
                    explanation("끈기는 함께 쌓아줘", "같은 퀘스트의 주간 목표를 2주 연속 달성하면 끈기 +1. 이후에도 연속으로 달성한 주마다 +1이야. 월간 목표는 같은 방식으로 2개월째부터 +1씩 쌓여. 한 번 퀘스트에는 연속 달성 보너스가 없어.")
                    explanation("오각형과 숫자", "오각형은 각 파라미터의 성장을 보여줘. 눈금은 시각적 가이드야. 정확한 누적 포인트는 숫자로 확인해.")
                    explanation("보관과 삭제", "보관한 퀘스트는 다시 꺼낼 수 있어. 삭제한 퀘스트는 복원할 수 없어. 둘 다 지금까지의 완료 기록과 획득 파라미터는 유지돼.")
                    explanation("잘못 기록했다면", "달성 화면이나 기록 탭에서 되돌릴 수 있어. 횟수와 포인트를 다시 계산하고, 이어진 끈기 보너스도 달라질 수 있어.")
                case .about:
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 84, height: 84).accessibilityHidden(true)
                    Text("PENTAPHOR").font(.custom("AvenirNextCondensed-HeavyItalic", size: 36, relativeTo: .largeTitle))
                    Eyebrow(title: BrandCopy.slogan)
                    Text(BrandCopy.tagline).font(.headline)
                    explanation("버전", "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    explanation("이 기기에 쌓이는 기록", "닉네임, 설정, 퀘스트, 완료 기록은 이 기기에 저장됩니다. 현재 앱은 계정 없이 이용할 수 있으며, 기록을 서버로 전송하거나 광고·분석 도구로 수집하지 않습니다.")
                    explanation("데이터 보관", "설정의 ‘백업 · 복원’에서 백업 파일을 저장하거나 불러올 수 있습니다. iCloud Drive 등 앱 밖의 위치에 파일을 보관해 주세요. 자동 클라우드 백업과 기기 간 동기화는 제공하지 않습니다. 앱을 삭제하면 기기에 저장된 기록과 복원 전 백업이 함께 삭제될 수 있습니다.")
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Palette.paper).foregroundStyle(Palette.ink)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
    private func explanation(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).lineSpacing(5).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}
