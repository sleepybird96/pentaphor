import SwiftUI
import PentaphorCore

struct SettingsView: View {
    let store: QuestStore
    @Environment(ChallengePurchaseService.self) private var purchases
    @State private var showChallenge = false
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
                    Button { showChallenge = true } label: {
                        settingsRow(purchases.entitlement.access == .unlocked ? AppLocalization.string("SettingsView.1") : AppLocalization.string("SettingsView.2"), symbol: "sparkles")
                    }.accessibilityIdentifier("settings.challenge")
                    nicknameSection
                    VStack(alignment: .leading, spacing: 13) {
                        sectionTitle(AppLocalization.string("SettingsView.3"))
                        Toggle(AppLocalization.string("SettingsView.4"), isOn: preferenceBinding(\.hapticsEnabled)).accessibilityIdentifier("settings.haptics")
                        Text(AppLocalization.string("SettingsView.5")).font(.caption).foregroundStyle(Palette.muted)
                        Divider()
                        Toggle(AppLocalization.string("SettingsView.6"), isOn: preferenceBinding(\.simplifiedEffects)).accessibilityIdentifier("settings.simple-effects")
                        Text(reduceMotion ? AppLocalization.string("SettingsView.7") : AppLocalization.string("SettingsView.8"))
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                    }
                    reminderSection
                    NavigationLink { BackupSettingsView(store: store) } label: {
                        settingsRow(AppLocalization.string("SettingsView.9"), symbol: "externaldrive")
                    }.accessibilityIdentifier("settings.backup")
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle(AppLocalization.string("SettingsView.10")).padding(.bottom, 9)
                        NavigationLink { GuideDetailView(page: .time, timeZoneID: store.engine.state.timeZoneID) } label: {
                            settingsRow(AppLocalization.string("SettingsView.11"), symbol: "globe.asia.australia", detail: store.engine.state.timeZoneID)
                        }.accessibilityIdentifier("settings.time")
                        Button { editingNickname = false; showIntroduction = true } label: {
                            settingsRow(AppLocalization.string("SettingsView.12"), symbol: "play.rectangle")
                        }.accessibilityIdentifier("settings.replay")
                        NavigationLink { GuideDetailView(page: .rules, timeZoneID: store.engine.state.timeZoneID) } label: {
                            settingsRow(AppLocalization.string("SettingsView.13"), symbol: "pentagon")
                        }.accessibilityIdentifier("settings.rules")
                        NavigationLink { GuideDetailView(page: .about, timeZoneID: store.engine.state.timeZoneID) } label: {
                            settingsRow(AppLocalization.string("SettingsView.14"), symbol: "info.circle")
                        }.accessibilityIdentifier("settings.about")
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.paper).foregroundStyle(Palette.ink)
            .navigationTitle(AppLocalization.string("SettingsView.15")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(AppLocalization.string("SettingsView.16")) { dismiss() }.accessibilityIdentifier("settings.done") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(AppLocalization.string("SettingsView.17")) { editingNickname = false } }
            }
            .fullScreenCover(isPresented: $showIntroduction) {
                IntroductionView(store: store, isReplay: true) { _ in showIntroduction = false }
            }
            .modifier(ErrorNotice(error: $error))
            .sheet(isPresented: $showChallenge) { ChallengePaywall(store: store, isPresented: $showChallenge) }
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
            sectionTitle(AppLocalization.string("SettingsView.18"))
            Toggle(AppLocalization.string("SettingsView.19"), isOn: Binding(
                get: { store.engine.preferences.remindersEnabled && reminderService.authorization == .allowed },
                set: { setRemindersEnabled($0) }
            ))
            .frame(minHeight: 44)
            .disabled(reminderActionRunning || reminderService.authorization == .unknown)
            .accessibilityIdentifier("settings.reminder.enabled")
            Text(AppLocalization.string("SettingsView.20"))
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            HStack {
                Text(AppLocalization.string("SettingsView.21")).font(.subheadline)
                Spacer()
                Text(reminderAuthorizationLabel).font(.subheadline.bold()).foregroundStyle(Palette.teal)
                    .accessibilityIdentifier("settings.reminder.authorization")
            }
            switch reminderService.authorization {
            case .denied:
                Text(AppLocalization.string("SettingsView.22"))
                    .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                Button(AppLocalization.string("SettingsView.23")) {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }.font(.subheadline.bold()).frame(minHeight: 44)
                    .accessibilityIdentifier("settings.reminder.open-settings")
            case .notDetermined:
                Text(AppLocalization.string("SettingsView.24"))
                    .font(.caption).foregroundStyle(Palette.muted)
            case .allowed:
                if store.engine.preferences.remindersEnabled {
                    Text(AppLocalization.format("SettingsView.25", AppLocalization.argument(reminderService.scheduledCount)))
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("settings.reminder.count")
                    Button(AppLocalization.string("SettingsView.26")) {
                        reminderActionRunning = true
                        testRequested = false
                        Task {
                            await reminderService.sendTest()
                            testRequested = reminderService.errorMessage == nil && reminderService.authorization == .allowed
                            reminderActionRunning = false
                        }
                    }.font(.subheadline.bold()).frame(minHeight: 44).disabled(reminderActionRunning)
                        .accessibilityIdentifier("settings.reminder.test")
                    Text(testRequested ? AppLocalization.string("SettingsView.27") : AppLocalization.string("SettingsView.28"))
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                        .accessibilityIdentifier("settings.reminder.test-status")
                } else {
                    Text(AppLocalization.string("SettingsView.29"))
                        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                }
            case .unknown:
                ProgressView(AppLocalization.string("SettingsView.30")).font(.caption)
            }
            if let message = reminderService.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red).lineSpacing(4)
                    .accessibilityIdentifier("settings.reminder.error")
                Button(AppLocalization.string("SettingsView.31")) {
                    reminderActionRunning = true
                    Task {
                        await reminderService.synchronize(state: store.engine.state)
                        reminderActionRunning = false
                    }
                }.font(.subheadline.bold()).frame(minHeight: 44).disabled(reminderActionRunning)
                    .accessibilityIdentifier("settings.reminder.retry")
            }
            Text(AppLocalization.string("SettingsView.32"))
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            Text(AppLocalization.format("SettingsView.33", AppLocalization.argument(store.engine.state.timeZoneID)))
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
            Text(AppLocalization.string("SettingsView.34"))
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
        case .unknown: AppLocalization.string("SettingsView.35")
        case .notDetermined: AppLocalization.string("SettingsView.36")
        case .denied: AppLocalization.string("SettingsView.37")
        case .allowed: AppLocalization.string("SettingsView.38")
        }
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(AppLocalization.string("SettingsView.39"))
            HStack {
                TextField(AppLocalization.string("SettingsView.40"), text: $nickname)
                    .font(.title3.bold()).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($editingNickname).submitLabel(.done).onSubmit(saveNickname)
                    .accessibilityIdentifier("settings.nickname")
                if !nickname.isEmpty {
                    Button { nickname = ""; savedNickname = false } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                    }.accessibilityLabel(AppLocalization.string("SettingsView.41")).accessibilityIdentifier("settings.nickname.clear")
                }
                Button(AppLocalization.string("SettingsView.42"), action: saveNickname).font(.subheadline.bold()).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("settings.nickname.save")
            }.padding(.leading, 12).background(Palette.ink.opacity(0.045))
            Text(savedNickname ? AppLocalization.string("SettingsView.43") : AppLocalization.string("SettingsView.44"))
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

enum GuidePage { case time, rules, about }

struct GuideDetailView: View {
    let page: GuidePage
    let timeZoneID: String
    private var title: String {
        switch page { case .time: AppLocalization.string("SettingsView.11"); case .rules: AppLocalization.string("SettingsView.13"); case .about: AppLocalization.string("SettingsView.47") }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                switch page {
                case .time:
                    explanation(AppLocalization.string("SettingsView.48"), AppLocalization.string("SettingsView.49"))
                    explanation(AppLocalization.string("SettingsView.50"), timeZoneID + AppLocalization.string("SettingsView.51"))
                    explanation(AppLocalization.string("SettingsView.52"), AppLocalization.string("SettingsView.53"))
                    explanation(AppLocalization.string("SettingsView.54"), AppLocalization.string("SettingsView.55"))
                case .rules:
                    explanation(AppLocalization.string("SettingsView.56"), AppLocalization.string("SettingsView.57"))
                    explanation(AppLocalization.string("SettingsView.58"), AppLocalization.string("SettingsView.59"))
                    explanation(AppLocalization.string("SettingsView.60"), AppLocalization.string("SettingsView.61"))
                    explanation(AppLocalization.string("SettingsView.62"), AppLocalization.string("SettingsView.63"))
                    explanation(AppLocalization.string("SettingsView.64"), AppLocalization.string("SettingsView.65"))
                case .about:
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 84, height: 84).accessibilityHidden(true)
                    Text("PENTAPHOR").font(.custom("AvenirNextCondensed-HeavyItalic", size: 36, relativeTo: .largeTitle))
                    Eyebrow(title: BrandCopy.slogan)
                    Text(BrandCopy.tagline).font(.headline)
                    explanation(AppLocalization.string("SettingsView.66"), "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                    explanation(AppLocalization.string("SettingsView.67"), AppLocalization.string("SettingsView.68"))
                    explanation(AppLocalization.string("SettingsView.69"), AppLocalization.string("SettingsView.70"))
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
