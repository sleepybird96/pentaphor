import SwiftUI
import PentaphorCore

struct QuestEditor: View {
    let store: QuestStore
    @Environment(ChallengePurchaseService.self) private var purchases
    @State private var showChallenge = false
    let quest: Quest?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var notes: String
    @State private var artID: String
    @State private var cadence: Cadence
    @State private var target: Int
    @State private var rewards: StatPoints
    @State private var reminderEnabled: Bool
    @State private var reminder: QuestReminder
    @State private var showArt = false
    @State private var error: String?
    @State private var confirmDeletion = false
    @State private var previewGrowth = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var showsFirstQuestHelp: Bool { quest == nil && !store.engine.preferences.hasCreatedFirstQuest }
    private enum Field: Hashable { case name, notes }
    @FocusState private var focusedField: Field?

    init(store: QuestStore, quest: Quest?) {
        self.store = store; self.quest = quest
        _name = State(initialValue: quest?.name ?? "")
        _notes = State(initialValue: quest?.notes ?? "")
        _artID = State(initialValue: quest?.artID ?? "climbing")
        _cadence = State(initialValue: quest?.cadence ?? .week)
        _target = State(initialValue: quest?.targetChanges.last?.target ?? 3)
        _rewards = State(initialValue: quest?.rewards ?? StatPoints(stamina: 1, courage: 1))
        _reminderEnabled = State(initialValue: quest?.reminder != nil)
        _reminder = State(initialValue: quest?.reminder ?? QuestReminder(weekdays: [2, 4, 6], hour: 20, minute: 0))
    }

    private var hasHistory: Bool { guard let quest else { return false }; return store.engine.state.completions.contains { $0.questID == quest.id } }
    private var valid: Bool {
        (1...40).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count)
            && rewards.total <= 2 && (!reminderEnabled || reminder.isValid)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 8) { Eyebrow(title: quest == nil ? "NEW QUEST" : "YOUR NEXT CHAPTER"); Text(quest == nil ? "무엇을 해볼까?" : "퀘스트 수정").font(.system(size: 31, weight: .black)) }
                    Button { focusedField = nil; showArt = true } label: {
                        ZStack(alignment: .leading) {
                            Palette.art
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 18) {
                                    Eyebrow(title: "MY NEXT CHAPTER", color: Palette.bright)
                                    Label("아트 바꾸기", systemImage: "arrow.up.right").font(.caption.bold()).foregroundStyle(Palette.paper)
                                }.padding(.leading, 16)
                                Spacer(minLength: 0)
                                QuestArt(id: artID).frame(width: 205, height: 205)
                            }
                        }.frame(height: 205).clipped()
                    }.buttonStyle(.plain).accessibilityIdentifier("quest.art").accessibilityLabel("아트 바꾸기, \(ArtCatalog.art(artID).label)")
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text("퀘스트 이름").font(.caption.bold()); Spacer(); Text("이름은 자유롭게").font(.caption2).foregroundStyle(Palette.muted) }
                        TextField("퀘스트 이름", text: $name).font(.system(size: 25, weight: .heavy)).padding(.vertical, 9)
                            .focused($focusedField, equals: .name).submitLabel(.done).onSubmit { focusedField = nil }
                            .accessibilityIdentifier("quest.name")
                        Rectangle().fill(focusedField == .name ? Palette.teal : Palette.ink).frame(height: 2)
                        if name.count > 40 { Text("40자 이내로 적어줘.").font(.caption).foregroundStyle(.red) }
                    }
                    if showsFirstQuestHelp {
                        Text("행동이 떠오르는 그림을 골라. 이름과 포인트는 자유롭게 정하면 돼.")
                            .font(.caption).foregroundStyle(Palette.teal).lineSpacing(4)
                            .accessibilityIdentifier("quest.first-help")
                    }
                    notesInput
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("나만의 페이스").font(.headline); Spacer(); Text("매일 하지 않아도 돼.").font(.caption2).foregroundStyle(Palette.muted) }
                        if showsFirstQuestHelp {
                            Text("한 번 해볼까, 주기적으로 이어갈까?").font(.subheadline).foregroundStyle(Palette.teal)
                        }
                        Picker("반복", selection: $cadence) { ForEach(Cadence.allCases, id: \.self) { Text($0.korean).tag($0) } }.pickerStyle(.segmented).disabled(hasHistory).accessibilityIdentifier("quest.cadence")
                        if cadence != .once {
                            Stepper(value: $target, in: 1...99) {
                                Text("목표 \(target)회").font(.system(.title3, design: .rounded, weight: .bold))
                            }.accessibilityIdentifier("quest.target")
                        }
                        Text(cadence.scheduleDescription)
                            .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                        if hasHistory {
                            Text(cadence == .once ? "첫 기록 이후에는 반복 방식을 바꿀 수 없어. 이미 받은 포인트는 그대로야." : "첫 기록 이후에는 주기를 바꿀 수 없어. 목표 횟수 변경은 이번 기간부터 바로 적용돼. 이미 받은 행동 포인트는 그대로야.")
                                .font(.caption).foregroundStyle(Palette.teal).lineSpacing(4)
                        }
                    }
                    QuestReminderFields(isEnabled: $reminderEnabled, reminder: $reminder,
                                        timeZoneID: store.engine.state.timeZoneID, globallyEnabled: store.engine.preferences.remindersEnabled)
                    allocation
                    if showsFirstQuestHelp {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(title: "GROWTH PREVIEW")
                            Text("완료하면 이렇게 쌓여").font(.headline)
                            Text("키우고 싶은 파라미터에 최대 2점을 나눠줘. 미리보기는 실제 기록에 반영되지 않아.")
                                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
                            ParameterRadar(before: .zero, after: rewards, progress: previewGrowth, dark: false,
                                           simplifiedEffects: store.engine.preferences.simplifiedEffects)
                                .accessibilityIdentifier("quest.reward-preview")
                        }.padding(16).background(Palette.teal.opacity(0.05))
                    }
                    PrimaryButton(title: quest == nil ? "나의 퀘스트로 등록" : "변경 내용 저장", action: save)
                        .disabled(!valid).opacity(valid ? 1 : 0.4).accessibilityIdentifier("quest.save.bottom")
                    if let quest {
                        Button("퀘스트 보관하기") {
                            do { try store.transact { try $0.setArchived(id: quest.id, archived: true) }; dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("quest.archive")
                        Text("보관해도 지금까지의 기록과 파라미터는 남아.").font(.caption).foregroundStyle(Palette.muted)
                        Button("퀘스트 삭제하기", role: .destructive) {
                            focusedField = nil
                            confirmDeletion = true
                        }.buttonStyle(.plain).font(.subheadline).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("quest.delete")
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.paper).foregroundStyle(Palette.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("저장", action: save).disabled(!valid).accessibilityIdentifier("quest.save") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("완료") { focusedField = nil } }
            }
            .sheet(isPresented: $showArt) { ArtPicker(selectedID: $artID).presentationDetents([.large]) }
            .alert("퀘스트를 삭제할까?", isPresented: $confirmDeletion) {
                Button("취소", role: .cancel) {}
                Button("삭제하기", role: .destructive) {
                    guard let quest else { return }
                    do {
                        try store.transact { try $0.delete(id: quest.id, at: Date()) }
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            } message: {
                Text("퀘스트는 복원할 수 없어. 지금까지의 완료 기록과 획득 파라미터는 그대로 남아.")
            }
            .task(id: Stat.allCases.map { rewards[$0] }) {
                guard showsFirstQuestHelp else { return }
                if store.engine.preferences.usesSimplifiedEffects(systemReduceMotion: reduceMotion) { previewGrowth = 1; return }
                previewGrowth = 0
                // Render the starting frame before animating the preview. Changing
                // both values in one update would coalesce them into the final frame.
                do { try await Task.sleep(for: .milliseconds(60)) } catch { return }
                withAnimation(.linear(duration: 0.95)) { previewGrowth = 1 }
            }
            .modifier(ErrorNotice(error: $error))
            .sheet(isPresented: $showChallenge) { ChallengePaywall(store: store, isPresented: $showChallenge) }
        }
    }

    private var notesInput: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("메모").font(.caption.bold())
                Spacer()
                Text("선택").font(.caption2).foregroundStyle(Palette.muted)
            }
            TextEditor(text: $notes)
                .focused($focusedField, equals: .notes)
                .font(.subheadline).scrollContentBackground(.hidden)
                .frame(height: 112)
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("준비물, 방법, 기억할 내용을 적어줘.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                            .padding(.horizontal, 5).padding(.top, 8)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .padding(10)
                .background(Palette.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(focusedField == .notes ? Palette.teal : Palette.ink.opacity(0.15), lineWidth: 1) }
                .accessibilityLabel("메모").accessibilityIdentifier("quest.notes")
        }
    }

    private var allocation: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("어떤 나로 자랄까?").font(.headline); Spacer(); Text("\(rewards.total) / 2 P").font(.system(.headline, design: .rounded, weight: .heavy)).foregroundStyle(Palette.teal) }.padding(.bottom, 14)
            Rectangle().fill(Palette.ink).frame(height: 1)
            ForEach(Stat.allCases) { stat in
                HStack {
                    Image(systemName: "diamond.fill").font(.system(size: 7)).foregroundStyle(rewards[stat] > 0 ? Palette.teal : Palette.muted.opacity(0.4))
                    Text(stat.title).font(.subheadline.weight(rewards[stat] > 0 ? .bold : .regular))
                    Spacer()
                    Button { rewards[stat] -= 1 } label: { Image(systemName: "minus").frame(width: 44, height: 46) }.disabled(rewards[stat] == 0).opacity(rewards[stat] == 0 ? 0.3 : 1).accessibilityLabel("\(stat.title) 포인트 줄이기")
                    Text("\(rewards[stat])").font(.system(size: 25, weight: .bold, design: .rounded)).frame(width: 23).accessibilityLabel("\(stat.title) \(rewards[stat])포인트")
                    Button { rewards[stat] += 1 } label: { Image(systemName: "plus").frame(width: 44, height: 46) }.disabled(rewards.total >= 2).opacity(rewards.total >= 2 ? 0.3 : 1).accessibilityLabel("\(stat.title) 포인트 늘리기")
                }.overlay(alignment: .bottom) { Rectangle().fill(Palette.ink.opacity(0.16)).frame(height: 1) }
            }
            Text(cadence == .once ? "완료하면 내가 정한 포인트가 쌓여.\n한 번 퀘스트에는 연속 달성 보너스가 없어." : "한 번 완료할 때마다 최대 2포인트.\n연속 목표 달성 보너스는 끈기에 따로 쌓여.")
                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(5).padding(.top, 13)
        }
    }

    private func save() {
        guard valid else { return }
        do {
            if quest == nil { try ChallengeQuestActions(store: store, purchases: purchases).requireCapacity() }
            try store.transact { engine in
                let savedID: UUID
                if let quest {
                    try engine.update(id: quest.id, name: name, artID: artID, cadence: cadence, target: cadence == .once ? 1 : target, rewards: rewards, at: Date(), notes: notes)
                    savedID = quest.id
                } else {
                    savedID = try engine.create(name: name, artID: artID, cadence: cadence, target: cadence == .once ? 1 : target, rewards: rewards, at: Date(), notes: notes).id
                }
                try engine.updateReminder(id: savedID, reminder: reminderEnabled ? reminder : nil)
            }
            dismiss()
        } catch ChallengeActionError.activeQuestLimit { showChallenge = true }
        catch { self.error = error.localizedDescription }
    }
}

struct ArtPicker: View {
    @Binding var selectedID: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category = "전체"
    private var filtered: [Art] {
        ArtCatalog.all.filter { (category == "전체" || $0.category == category) && (search.isEmpty || "\($0.label) \($0.keywords) \($0.category)".localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(title: "PICK YOUR NEXT MOVE")
                    Text("끌리는 장면을 골라봐.").font(.title2.bold())
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(["전체"] + ArtCatalog.categories, id: \.self) { value in
                                Button { category = value } label: {
                                    Text(value).font(.caption.bold()).padding(.horizontal, 14).frame(minHeight: 44)
                                        .foregroundStyle(category == value ? Palette.paper : Palette.ink)
                                        .background(category == value ? Palette.teal : Palette.ink.opacity(0.06))
                                }.buttonStyle(.plain).accessibilityAddTraits(category == value ? .isSelected : [])
                            }
                        }
                    }
                    Text("\(filtered.count)개의 장면").font(.caption).foregroundStyle(Palette.muted)
                    if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                        ForEach(filtered) { art in
                            Button { selectedID = art.id; dismiss() } label: {
                                QuestArt(id: art.id, pixelSize: 360).aspectRatio(1, contentMode: .fit).background(Palette.art)
                                    .overlay { if art.id == selectedID { Rectangle().strokeBorder(Palette.teal, lineWidth: 3) } }
                                    .overlay(alignment: .topTrailing) { if art.id == selectedID { Image(systemName: "checkmark").font(.caption.bold()).padding(7).foregroundStyle(Palette.paper).background(Palette.teal) } }
                            }.buttonStyle(.plain).accessibilityLabel(art.label).accessibilityIdentifier("art.\(art.id)").accessibilityAddTraits(art.id == selectedID ? .isSelected : [])
                        }
                    }
                }.padding(24)
            }.background(Palette.paper).foregroundStyle(Palette.ink)
                .navigationTitle("아트 고르기").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "행동이나 장면 검색")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }
}
