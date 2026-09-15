import SwiftUI
import PentaphorCore

struct StatsView: View {
    let store: QuestStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                VStack(alignment: .leading, spacing: 8) { Eyebrow(title: BrandCopy.slogan); Text(store.engine.preferences.nickname.isEmpty ? "나의 파라미터" : "\(store.engine.preferences.nickname)의 파라미터").font(.system(size: 32, weight: .black)) }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) { Text("TOTAL GROWTH").font(.caption.monospaced().bold()); Spacer(); Text("\(store.engine.totals.total) P").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Palette.bright) }.padding(22)
                    ParameterRadar(before: store.engine.totals, after: store.engine.totals).padding(.horizontal, 10)
                }.foregroundStyle(Palette.paper).background(Palette.ink)
                ForEach(Stat.allCases) { stat in
                    HStack { Label(stat.title, systemImage: "diamond.fill").font(.body.bold()); Spacer(); Text("\(store.engine.totals[stat])").font(.system(size: 25, weight: .heavy, design: .rounded)).foregroundStyle(Palette.teal) }.padding(.vertical, 3)
                }
                Text("완료한 행동의 포인트와 연속 달성 보너스가 모인 지금의 나. 되돌린 기록은 파라미터에서도 빠져.").font(.caption).lineSpacing(5).foregroundStyle(Palette.muted)
                Divider()
                Eyebrow(title: "MY TIME, MY RHYTHM")
                Label(store.engine.state.timeZoneID, systemImage: "globe.asia.australia").font(.subheadline.bold())
                Text("처음 시작한 시간대로 주·월을 집계해. 여행 중에도 기록의 기준은 같아. 주는 월요일 0시, 월은 1일 0시에 시작해.").font(.caption).foregroundStyle(Palette.muted).lineSpacing(5)
            }.padding(24)
        }
    }
}

struct HistoryView: View {
    let store: QuestStore
    let recapNow: () -> Date
    let onWeeklyRecap: (WeeklyRecap) -> Void
    let onDialogChange: (Bool) -> Void
    @State private var error: String?
    @State private var undoID: UUID?
    private var records: [Completion] { store.engine.state.completions.sorted { $0.recordedAt > $1.recordedAt } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) { Eyebrow(title: "EVERY STEP STAYS"); Text("쌓아온 기록").font(.system(size: 32, weight: .black)) }
                if let report = WeeklyRecapBuilder.latest(engine: store.engine, now: recapNow()) {
                    Button { onWeeklyRecap(report) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles").foregroundStyle(Palette.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("주간 정산 다시 보기").font(.subheadline.bold())
                                Text("\(periodDate(report.period.start)) 시작 · \(report.completionCount)번의 행동")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }.padding(16).frame(minHeight: 44).background(Palette.teal.opacity(0.07), in: CutCorner())
                    }.buttonStyle(.plain).accessibilityIdentifier("history.weekly-recap")
                }
                if records.isEmpty { ContentUnavailableView("첫걸음을 기다리는 중", systemImage: "clock", description: Text("퀘스트를 완료하면 여기에 차곡차곡 쌓여.")) }
                ForEach(records) { record in
                    let quest = store.engine.state.quests.first { $0.id == record.questID }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 13) {
                            if let quest { QuestArt(id: quest.artID, pixelSize: 240).frame(width: 58, height: 58).background(Palette.art) }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(quest?.name ?? "퀘스트").font(.body.bold())
                                Text(record.recordedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            if record.isVoided { Text("되돌린 기록").font(.caption2).foregroundStyle(Palette.muted) }
                            else { Button("되돌리기") { undoID = record.id }.font(.caption.bold()).frame(minHeight: 44).accessibilityLabel("\(quest?.name ?? "퀘스트") 기록 되돌리기") }
                        }.opacity(record.isVoided ? 0.55 : 1)
                        HStack {
                            Text(record.period.cadence == .once ? "한 번 · 완료" : "\(periodDate(record.period.start)) 시작 · 목표 \(record.target)회")
                            Spacer()
                            Text(Stat.allCases.filter { record.rewards[$0] > 0 }.map { "\($0.title) +\(record.rewards[$0])" }.joined(separator: " · "))
                        }.font(.caption2).foregroundStyle(Palette.muted)
                        Divider()
                    }
                }
            }.padding(24)
        }.modifier(ErrorNotice(error: $error))
            .confirmationDialog("이 기록을 되돌릴까?", isPresented: Binding(get: { undoID != nil }, set: { if !$0 { undoID = nil } }), titleVisibility: .visible) {
                Button("기록 되돌리기", role: .destructive) {
                    guard let undoID else { return }
                    do { try store.transact { try $0.undo(completionID: undoID) } }
                    catch { self.error = error.localizedDescription }
                    self.undoID = nil
                }
            } message: { Text("횟수와 포인트를 다시 계산해. 이 기록과 이어진 연속 달성 보너스도 달라질 수 있어.") }
            .onChange(of: undoID != nil || error != nil, initial: true) { _, busy in onDialogChange(busy) }
            .onDisappear { onDialogChange(false) }
    }
    private func periodDate(_ date: Date) -> String {
        let format = DateFormatter(); format.locale = Locale(identifier: "ko_KR"); format.timeZone = TimeZone(identifier: store.engine.state.timeZoneID); format.dateFormat = "M월 d일"
        return format.string(from: date)
    }
}

struct ArchiveView: View {
    let store: QuestStore
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    Eyebrow(title: "A CHAPTER TO RETURN TO")
                    Text("잠시 쉬어가는 퀘스트").font(.title2.bold())
                    Text("지금까지의 기록은 그대로.\n다시 이어가고 싶을 때 꺼내면 돼.").font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(5)
                    let archived = store.engine.archivedQuests
                    if archived.isEmpty { ContentUnavailableView("보관한 퀘스트가 없어", systemImage: "archivebox") }
                    ForEach(archived) { quest in
                        HStack(spacing: 12) {
                            QuestArt(id: quest.artID, pixelSize: 240).frame(width: 64, height: 64).background(Palette.art)
                            Text(quest.name).font(.body.bold()); Spacer()
                            Button("복원") {
                                do { try store.transact { try $0.setArchived(id: quest.id, archived: false) } }
                                catch { self.error = error.localizedDescription }
                            }.font(.subheadline.bold()).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("quest.restore.\(quest.name)")
                        }
                        Divider()
                    }
                }.padding(24)
            }.background(Palette.paper).foregroundStyle(Palette.ink)
                .navigationTitle("보관함").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() }.accessibilityIdentifier("archive.done") } }
                .modifier(ErrorNotice(error: $error))
        }
    }
}
