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
    @State private var tab = 0
    @State private var editor: QuestEditorPresentation?
    @State private var showArchive = false
    @State private var achievement: AchievementPresentation?
    @State private var graceQuest: Quest?
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var foregroundDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            BrandBar()
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = max(context.date, foregroundDate)
                Group {
                    switch tab {
                    case 1: StatsView(store: store)
                    case 2: HistoryView(store: store)
                    default: questList(now: now)
                    }
                }
            }
        }
        .foregroundStyle(Palette.ink).background(Palette.paper)
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sheet(item: $editor) { presentation in QuestEditor(store: store, quest: presentation.quest) }
        .sheet(isPresented: $showArchive) { ArchiveView(store: store) }
        .fullScreenCover(item: $achievement) { presentation in
            AchievementView(store: store, quest: presentation.quest, result: presentation.result)
        }
        .confirmationDialog("어느 주에 기록할까?", isPresented: Binding(get: { graceQuest != nil }, set: { if !$0 { graceQuest = nil } }), titleVisibility: .visible) {
            if let quest = graceQuest {
                Button("이번 주에 기록 (기본)") { complete(quest, previousWeek: false) }
                Button("지난주에 기록") { complete(quest, previousWeek: true) }
            }
            Button("취소", role: .cancel) { graceQuest = nil }
        } message: { Text("월요일 오전 9시 전까지 지난주 기록을 선택할 수 있어.") }
        .modifier(ErrorNotice(error: $error))
        .onChange(of: scenePhase) { _, phase in if phase == .active { foregroundDate = Date() } }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("퀘스트", symbol: "square.stack", value: 0, id: "tab.quests")
            tabButton("파라미터", symbol: "pentagon", value: 1, id: "tab.stats")
            tabButton("기록", symbol: "clock.arrow.circlepath", value: 2, id: "tab.history")
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
                    VStack(alignment: .leading, spacing: 8) { Eyebrow(title: "MY NEXT CHAPTER"); Text("나의 퀘스트").font(.system(size: 32, weight: .black)) }
                    Spacer()
                    Button { showArchive = true } label: { Image(systemName: "archivebox").font(.title3).frame(width: 44, height: 44) }
                        .accessibilityLabel("보관한 퀘스트").accessibilityIdentifier("quest.archived")
                }
                if store.engine.activeQuests.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "pentagon").font(.system(size: 70, weight: .ultraLight)).foregroundStyle(Palette.teal)
                        Text("아직 비어 있는 첫 페이지").font(.title2.bold())
                        Text("작은 행동 하나가\n다음의 나를 만들어.").font(.body).lineSpacing(6).foregroundStyle(Palette.muted)
                        Eyebrow(title: "START SMALL. GROW YOUR WAY.")
                    }.padding(.vertical, 42).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Cadence.allCases, id: \.self) { cadence in
                        let quests = store.engine.activeQuests.filter { $0.cadence == cadence }
                        if !quests.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack { Text(cadence.periodLabel).font(.headline); Spacer(); Text("\(quests.count) QUESTS").font(.caption.monospaced()).foregroundStyle(Palette.muted) }.padding(.bottom, 8)
                                ForEach(quests) { quest in questRow(quest, now: now) }
                            }
                        }
                    }
                }
                PrimaryButton(title: "새 퀘스트 만들기") { editor = QuestEditorPresentation(quest: nil) }.accessibilityIdentifier("quest.create")
                Text("매일 하지 않아도 돼. 네 페이스로 이어가면 돼.")
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
                        Text("\(progress.count) / \(progress.target)회 · \(quest.cadence.korean)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Palette.teal)
                            .accessibilityIdentifier("quest.progress.\(quest.name)")
                        if progress.achieved { Text("목표 달성 ✓").font(.caption2).foregroundStyle(Palette.muted) }
                        Label("수정", systemImage: "pencil")
                            .font(.caption.bold()).foregroundStyle(Palette.teal)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("quest.edit.\(quest.name)")
                .accessibilityHint("퀘스트 이름과 목표, 포인트를 수정해.")
            Button {
                let now = Date()
                if store.engine.canRecordPreviousWeek(for: quest, at: now) {
                    graceQuest = quest
                } else { complete(quest, previousWeek: false) }
            } label: {
                Image(systemName: "checkmark").font(.title3.bold()).frame(width: 44, height: 48).background(Palette.ink).foregroundStyle(Palette.bright)
            }.buttonStyle(.plain).accessibilityLabel("\(quest.name) 1회 완료").accessibilityIdentifier("quest.complete.\(quest.name)")
        }.padding(.vertical, 15).overlay(alignment: .bottom) { Rectangle().fill(Palette.ink.opacity(0.15)).frame(height: 1) }
    }

    private func complete(_ quest: Quest, previousWeek: Bool) {
        graceQuest = nil
        do {
            let result = try store.transact { try $0.complete(questID: quest.id, at: Date(), previousWeek: previousWeek) }
            achievement = AchievementPresentation(quest: quest, result: result)
        } catch { self.error = error.localizedDescription }
    }
}
