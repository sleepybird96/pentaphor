import SwiftUI
import PentaphorCore

struct AchievementView: View {
    let store: QuestStore
    let quest: Quest
    let result: CompletionResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var artVisible = false
    @State private var rewardsVisible = false
    @State private var growth = 0.0
    @State private var error: String?

    private var progress: QuestProgress { store.engine.progress(for: quest, at: result.completion.period.start) }
    var body: some View {
        VStack(spacing: 0) {
            BrandBar(dark: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .leading) {
                        Palette.art
                        QuestArt(id: quest.artID).frame(width: 285, height: 285).frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(x: artVisible ? 0 : 35, y: artVisible ? 0 : 10).opacity(artVisible ? 1 : 0)
                        VStack(alignment: .leading, spacing: -24) {
                            Text("WELL").foregroundStyle(Palette.paper)
                            Text("DONE!").foregroundStyle(Palette.bright)
                        }.font(.custom("AvenirNextCondensed-HeavyItalic", size: 70, relativeTo: .largeTitle))
                            .lineSpacing(-16).rotationEffect(.degrees(-8)).shadow(color: Palette.teal, radius: 0, x: 3, y: 4).padding(.leading, 19)
                        VStack {
                            Eyebrow(title: "THIS MOMENT BECOMES YOU.", color: Palette.paper.opacity(0.75)).frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Text("1회 완료 ✓").font(.caption.bold()).padding(.horizontal, 15).padding(.vertical, 7)
                                .foregroundStyle(Palette.ink).background(Palette.paper).rotationEffect(.degrees(-5)).frame(maxWidth: .infinity, alignment: .trailing)
                        }.padding(21)
                    }.frame(height: 275).clipped()
                    VStack(alignment: .leading, spacing: 12) {
                        Text(quest.name).font(.system(size: 29, weight: .heavy)).accessibilityIdentifier("achievement.title")
                        Text("한 번의 도전이, 네 안에 남았어.").font(.caption).foregroundStyle(Palette.paper.opacity(0.75))
                        rewardsRow.opacity(rewardsVisible ? 1 : 0).offset(y: rewardsVisible ? 0 : 10)
                        ParameterRadar(before: result.before, after: result.after, progress: growth)
                        HStack { Text("┄ 조금 전의 나"); Spacer(); Text("한 걸음 더 자랐어").foregroundStyle(Palette.gold) }.font(.caption2).foregroundStyle(Palette.paper.opacity(0.65))
                        Rectangle().fill(Palette.paper.opacity(0.16)).frame(height: 1).padding(.top, 5)
                        HStack {
                            Text("목표까지 남긴 발걸음").font(.subheadline.bold()); Spacer()
                            Text("\(progress.count)").font(.system(size: 29, weight: .black, design: .rounded)) + Text(" / \(progress.target)회").font(.caption)
                        }
                        ProgressView(value: min(Double(progress.count) / Double(progress.target), 1)).tint(Palette.bright)
                        Text(progress.achieved ? "목표 달성! 네 페이스를 찾았어." : "네 페이스로 이어가면 돼.").font(.caption2).foregroundStyle(Palette.paper.opacity(0.65))
                        if result.bonus > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(title: "KEEP YOUR OWN RHYTHM", color: Palette.gold)
                                Text("\(result.streak)\(result.completion.period.cadence == .week ? "주" : "개월") 연속 달성 · 끈기 +\(result.bonus)").font(.subheadline.bold()).foregroundStyle(Palette.gold)
                                Text("꾸준히 돌아온 너에게, 보너스가 쌓였어.").font(.caption2)
                            }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Palette.gold.opacity(0.09))
                        }
                        PrimaryButton(title: "좋아, 이만큼 자랐어", dark: true) { dismiss() }.accessibilityIdentifier("achievement.done").padding(.top, 8)
                        Button("방금 기록 되돌리기") {
                            do { try store.transact { try $0.undo(completionID: result.completion.id) }; dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.font(.caption).underline().foregroundStyle(Palette.paper.opacity(0.7)).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("achievement.undo")
                    }.padding(24)
                }
            }
        }.background(Palette.ink).foregroundStyle(Palette.paper)
            .preferredColorScheme(.dark)
            .modifier(ErrorNotice(error: $error))
            .sensoryFeedback(.success, trigger: artVisible)
            .task {
                if reduceMotion { artVisible = true; rewardsVisible = true; growth = 1; return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { artVisible = true }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { rewardsVisible = true }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.95)) { growth = 1 }
            }
    }

    private var rewardsRow: some View {
        HStack(spacing: 8) {
            ForEach(Stat.allCases.filter { result.completion.rewards[$0] > 0 }) { stat in
                HStack {
                    Text(stat.title).font(.subheadline.bold()); Spacer()
                    Text("+\(result.completion.rewards[stat])").font(.system(size: 28, weight: .heavy, design: .rounded))
                }.padding(.horizontal, 14).padding(.vertical, 8).foregroundStyle(Palette.ink)
                    .background(stat == .courage ? Palette.bright : Palette.paper, in: CutCorner())
            }
            if result.completion.rewards.total == 0 { Text("오늘의 행동이 기록되었어 ✓").font(.subheadline.bold()).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.teal) }
        }.padding(.top, 4)
    }
}
