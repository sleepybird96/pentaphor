import SwiftUI
import PentaphorCore

struct SettingsView: View {
    let store: QuestStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nickname: String
    @State private var savedNickname = false
    @State private var showIntroduction = false
    @State private var error: String?
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
        }.tint(Palette.teal)
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
                    explanation("집계 시간대", timeZoneID + "\n처음 시작한 시간대를 유지해. 여행 중에도 주·월 기록의 기준은 바뀌지 않아.")
                    explanation("한 주는 월요일 0시부터", "새 주는 월요일 0시에 시작해. 월요일 오전 9시 전까지는 완료할 때 ‘지난주에 기록’을 선택할 수 있어. 기본은 이번 주 기록이야.")
                    explanation("한 달은 1일 0시부터", "월간 목표는 매월 1일 0시에 새로 시작해. 월간 기록에는 주간과 같은 유예 시간이 없어.")
                case .rules:
                    explanation("다섯 파라미터", "체력 · 지식 · 끈기 · 매력 · 용기\n어떤 행동이 무엇을 키울지는 네가 정해. 한 번 완료할 때 받을 포인트를 최대 2점까지 나눌 수 있어.")
                    explanation("끈기는 함께 쌓아줘", "같은 퀘스트의 주간 목표를 2주 연속 달성하면 끈기 +1. 이후에도 연속으로 달성한 주마다 +1이야. 월간 목표는 같은 방식으로 2개월째부터 +1씩 쌓여.")
                    explanation("오각형과 숫자", "오각형은 각 파라미터의 성장을 보여줘. 눈금은 시각적 가이드야. 정확한 누적 포인트는 숫자로 확인해.")
                    explanation("보관과 삭제", "보관한 퀘스트는 다시 꺼낼 수 있어. 삭제한 퀘스트는 복원할 수 없어. 둘 다 지금까지의 완료 기록과 획득 파라미터는 유지돼.")
                    explanation("잘못 기록했다면", "달성 화면이나 기록 탭에서 되돌릴 수 있어. 횟수와 포인트를 다시 계산하고, 이어진 끈기 보너스도 달라질 수 있어.")
                case .about:
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 84, height: 84).accessibilityHidden(true)
                    Text("PENTAPHOR").font(.custom("AvenirNextCondensed-HeavyItalic", size: 36, relativeTo: .largeTitle))
                    Eyebrow(title: BrandCopy.slogan)
                    Text(BrandCopy.tagline).font(.headline)
                    explanation("버전", "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    explanation("이 기기에 쌓이는 기록", "닉네임, 설정, 퀘스트, 완료 기록은 이 기기에 저장돼. 현재 앱은 계정 없이 작동하며, 기록을 서버로 전송하거나 광고·분석 도구로 수집하지 않아.")
                    explanation("데이터 보관", "현재 앱 자체의 클라우드 동기화나 백업·복원 기능은 없어. 앱을 삭제하면 기기에 저장된 기록이 함께 삭제될 수 있어.")
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
