import SwiftUI
import PentaphorCore

private struct AchievementPresentation: Identifiable {
    let id = UUID()
    let quest: Quest
    let result: CompletionResult
}

private struct QuestEditorPresentation: Identifiable {
    let id = UUID()
    let quest: Quest?
}

struct QuestHome: View {
    let store: QuestStore
    @Environment(ChallengePurchaseService.self) private var purchases
    @State private var showChallenge = false
    @State private var challengeUnlock = ChallengeUnlockCoordinator()
    let recapNow: () -> Date
    @Environment(QuestReminderService.self) private var reminders
    @State private var tab = 0
    @State private var recap = WeeklyRecapCoordinator()
    @State private var recapError: String?
    @State private var historyDialogIsPresented = false
    @State private var editor: QuestEditorPresentation?
    @State private var showArchive = false
    @State private var showSettings = false
    @State private var showIntroduction: Bool
    @State private var createAfterIntroduction = false
    @State private var completionAction = QuestCompletionAction()

    init(store: QuestStore, recapNow: @escaping () -> Date = Date.init) {
        self.store = store
        self.recapNow = recapNow
        _showIntroduction = State(initialValue: !store.engine.preferences.hasCompletedOnboarding)
    }
    @State private var achievement: AchievementPresentation?
    @State private var graceQuest: Quest?
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var foregroundDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            BrandBar(onSettings: { showSettings = true })
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = max(context.date, foregroundDate)
                Group {
                    switch tab {
                    case 1: StatsView(store: store)
                    case 2: HistoryView(store: store, recapNow: recapNow, onWeeklyRecap: { recap.show($0) }, onDialogChange: { busy in
                        historyDialogIsPresented = busy
                        if !busy { drainAfterDialog() }
                    })
                    default: questList(now: now)
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink).background(Palette.paper)
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .fullScreenCover(item: Binding(get: { challengeUnlock.presentation }, set: { _ in }), onDismiss: drainPresentations) { _ in
            ChallengeUnlockView(store: store) { challengeUnlock.finish() }
        }
        .onChange(of: purchases.unlockEvents) { _, _ in drainPresentations() }
        .sheet(item: $editor, onDismiss: drainPresentations) { presentation in QuestEditor(store: store, quest: presentation.quest) }
        .sheet(isPresented: $showChallenge, onDismiss: drainPresentations) { ChallengePaywall(store: store, isPresented: $showChallenge) }
        .sheet(isPresented: $showSettings, onDismiss: drainPresentations) { SettingsView(store: store) }
        .fullScreenCover(isPresented: $showIntroduction, onDismiss: {
            if reminders.pendingQuestID != nil { openReminderQuest() }
            else if createAfterIntroduction {
                createAfterIntroduction = false
                editor = QuestEditorPresentation(quest: nil)
            }
            drainPresentations()
        }) {
            IntroductionView(store: store) { createQuest in
                createAfterIntroduction = createQuest
                showIntroduction = false
            }
        }
        .sheet(isPresented: $showArchive, onDismiss: drainPresentations) { ArchiveView(store: store) }
        .fullScreenCover(item: $achievement, onDismiss: drainPresentations) { presentation in
            AchievementView(store: store, quest: presentation.quest, result: presentation.result)
        }
        .fullScreenCover(item: Binding(get: { recap.presentation }, set: { _ in }), onDismiss: drainPresentations) { report in
            WeeklyRecapView(recap: report, timeZoneID: store.engine.state.timeZoneID,
                            simplifiedEffects: store.engine.preferences.simplifiedEffects) {
                do { try recap.finish(store: store, at: recapNow()) }
                catch { recapError = error.localizedDescription }
            }
            .interactiveDismissDisabled()
            .modifier(ErrorNotice(error: $recapError))
        }
        .confirmationDialog(AppLocalization.string("QuestHome.1"), isPresented: Binding(get: { graceQuest != nil }, set: { if !$0 { graceQuest = nil } }), titleVisibility: .visible) {
            if let quest = graceQuest {
                Button(AppLocalization.string("QuestHome.2")) { complete(quest, previousWeek: false) }
                Button(AppLocalization.string("QuestHome.3")) { complete(quest, previousWeek: true) }
            }
            Button(AppLocalization.string("QuestHome.4"), role: .cancel) { graceQuest = nil }
        } message: { Text(AppLocalization.string("QuestHome.5")) }
        .modifier(ErrorNotice(error: $error))
        .task {
            recap.requestCheck()
            drainPresentations()
        }
        .onChange(of: reminders.pendingQuestID, initial: true) { _, _ in drainPresentations() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                foregroundDate = Date()
                recap.requestCheck()
                drainPresentations()
            }
        }
        .onChange(of: store.replacementGeneration) { _, _ in
            recap.requestCheck()
            foregroundDate = Date()
            drainPresentations()
        }
        .onChange(of: graceQuest?.id) { _, id in
            if id == nil { drainAfterDialog() }
        }
        .onChange(of: error) { _, value in
            if value == nil { drainAfterDialog() }
        }
    }

    private func drainPresentations() {
        guard recap.presentation == nil else { return }
        if reminders.pendingQuestID != nil {
            openReminderQuest()
            return
        }
        let busy = showChallenge || editor != nil || showSettings || showArchive || showIntroduction
            || achievement != nil || graceQuest != nil || error != nil || historyDialogIsPresented
        if !busy {
            for event in purchases.unlockEvents { challengeUnlock.enqueue(event: event); purchases.consumeUnlock(event.id) }
        }
        challengeUnlock.presentIfPossible(store: store, isBusy: busy)
        recap.presentIfPossible(engine: store.engine, now: recapNow(), isBusy: busy || challengeUnlock.presentation != nil)
    }

    private func drainAfterDialog() {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            drainPresentations()
        }
    }

    private func openReminderQuest() {
        guard recap.presentation == nil, challengeUnlock.presentation == nil else { return }
        guard let id = reminders.pendingQuestID else { return }
        tab = 0
        // Wait for the actual dismissal callback before presenting another sheet.
        if editor != nil { editor = nil; return }
        if showChallenge { showChallenge = false; return }
        if showSettings { showSettings = false; return }
        if showArchive { showArchive = false; return }
        if achievement != nil { achievement = nil; return }
        if showIntroduction {
            createAfterIntroduction = false
            showIntroduction = false
            return
        }
        if graceQuest != nil || error != nil {
            graceQuest = nil
            error = nil
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                openReminderQuest()
            }
            return
        }
        reminders.pendingQuestID = nil
        if let quest = store.engine.activeQuests.first(where: { $0.id == id }) {
            editor = QuestEditorPresentation(quest: quest)
        } else { drainPresentations() }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(AppLocalization.string("QuestHome.6"), symbol: "square.stack", value: 0, id: "tab.quests")
            tabButton(AppLocalization.string("QuestHome.7"), symbol: "pentagon", value: 1, id: "tab.stats")
            tabButton(AppLocalization.string("QuestHome.8"), symbol: "clock.arrow.circlepath", value: 2, id: "tab.history")
        }
        .padding(.top, 12).padding(.bottom, 8).background(Palette.paper)
        .overlay(alignment: .top) { Rectangle().fill(Palette.ink.opacity(0.15)).frame(height: 1) }
    }

    private func tabButton(_ title: String, symbol: String, value: Int, id: String) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 19, weight: .semibold)); Text(title).font(.caption2.bold()) }
                .foregroundStyle(tab == value ? Palette.teal : Palette.muted).frame(maxWidth: .infinity).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier(id).accessibilityAddTraits(tab == value ? .isSelected : [])
    }

    private func questList(now: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) { Eyebrow(title: BrandCopy.slogan); Text(AppLocalization.string("QuestHome.9")).font(.system(size: 32, weight: .black)) }
                    Spacer()
                    Button { showArchive = true } label: { Image(systemName: "archivebox").font(.title3).frame(width: 44, height: 44) }
                        .accessibilityLabel(AppLocalization.string("QuestHome.10")).accessibilityIdentifier("quest.archived")
                }
                if store.engine.activeQuests.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "pentagon").font(.system(size: 70, weight: .ultraLight)).foregroundStyle(Palette.teal)
                        Text(store.engine.state.completions.isEmpty ? AppLocalization.string("QuestHome.11") : AppLocalization.string("QuestHome.12")).font(.title2.bold())
                        Text(BrandCopy.tagline).font(.body).lineSpacing(6).foregroundStyle(Palette.muted)
                        Eyebrow(title: "ONE QUEST AT A TIME.")
                    }.padding(.vertical, 42).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(store.engine.activeQuests) { quest in questRow(quest, now: now) }
                    }
                }
                PrimaryButton(title: AppLocalization.string("QuestHome.13")) {
                    do { try ChallengeQuestActions(store: store, purchases: purchases).requireCapacity(); editor = QuestEditorPresentation(quest: nil) }
                    catch ChallengeActionError.activeQuestLimit { showChallenge = true }
                    catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("quest.create")
                Text(AppLocalization.string("QuestHome.14"))
                    .font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
            }.padding(24)
        }
    }

    private func questRow(_ quest: Quest, now: Date) -> some View {
        let progress = store.engine.progress(for: quest, at: now)
        return HStack(spacing: 12) {
            Button { editor = QuestEditorPresentation(quest: quest) } label: {
                HStack(spacing: 12) {
                    QuestArt(id: quest.artID, pixelSize: 240).frame(width: 72, height: 72).background(Palette.art)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(quest.name).font(.system(.body, weight: .bold)).multilineTextAlignment(.leading)
                        if let notes = quest.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(notes).font(.caption).foregroundStyle(Palette.muted)
                                .multilineTextAlignment(.leading).lineLimit(2)
                                .accessibilityIdentifier("quest.notes.preview.\(quest.name)")
                        }
                        Text(quest.cadence == .once ? AppLocalization.string("QuestHome.15") : AppLocalization.format("QuestHome.16", AppLocalization.argument(progress.count), AppLocalization.argument(progress.target), AppLocalization.argument(quest.cadence.korean)))
                            .font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Palette.teal)
                            .accessibilityIdentifier("quest.progress.\(quest.name)")
                        if progress.achieved { Text(AppLocalization.string("QuestHome.17")).font(.caption2).foregroundStyle(Palette.muted) }
                        Label(AppLocalization.string("QuestHome.18"), systemImage: "pencil")
                            .font(.caption.bold()).foregroundStyle(Palette.teal)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("quest.edit.\(quest.name)")
                .accessibilityHint(AppLocalization.string("QuestHome.19"))
            Button {
                let now = Date()
                if store.engine.canRecordPreviousWeek(for: quest, at: now) {
                    graceQuest = quest
                } else { complete(quest, previousWeek: false) }
            } label: {
                Image(systemName: "checkmark").font(.title3.bold()).frame(width: 44, height: 48).background(Palette.ink).foregroundStyle(Palette.bright)
            }.buttonStyle(.plain).accessibilityLabel(AppLocalization.format("QuestHome.20", AppLocalization.argument(quest.name))).accessibilityIdentifier("quest.complete.\(quest.name)")
        }.padding(.vertical, 15).overlay(alignment: .bottom) { Rectangle().fill(Palette.ink.opacity(0.15)).frame(height: 1) }
    }

    private func complete(_ quest: Quest, previousWeek: Bool) {
        graceQuest = nil
        do {
            let result = try completionAction.perform(store: store, questID: quest.id, at: Date(), previousWeek: previousWeek)
            achievement = AchievementPresentation(quest: quest, result: result)
        } catch { self.error = error.localizedDescription }
    }
}
