import SwiftUI
import PentaphorCore

struct AchievementView: View {
    let store: QuestStore
    @Environment(ChallengePurchaseService.self) private var purchases
    @State private var reachedCap = false
    @State private var showChallenge = false
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
                            Text(AppLocalization.string("AchievementView.1")).font(.caption.bold()).padding(.horizontal, 15).padding(.vertical, 7)
                                .foregroundStyle(Palette.ink).background(Palette.paper).rotationEffect(.degrees(-5)).frame(maxWidth: .infinity, alignment: .trailing)
                        }.padding(21)
                    }.frame(height: 275).clipped()
                    VStack(alignment: .leading, spacing: 12) {
                        Text(quest.name).font(.system(size: 29, weight: .heavy)).accessibilityIdentifier("achievement.title")
                        Text(AppLocalization.string("AchievementView.2")).font(.caption).foregroundStyle(Palette.paper.opacity(0.75))
                        rewardsRow.opacity(rewardsVisible ? 1 : 0).offset(y: rewardsVisible ? 0 : 10)
                        ParameterRadar(before: result.before, after: result.after, progress: growth, simplifiedEffects: store.engine.preferences.simplifiedEffects)
                        if purchases.entitlement.access == .free && Stat.allCases.contains(where: { result.after[$0] > 99 }) {
                            Text(AppLocalization.string("AchievementView.3")).font(.caption).foregroundStyle(Palette.gold)
                        }
                        if reachedCap && purchases.entitlement.access == .free {
                            Button(AppLocalization.string("AchievementView.4")) { showChallenge = true }.font(.subheadline.bold()).foregroundStyle(Palette.bright)
                        }
                        HStack { Text(AppLocalization.string("AchievementView.5")); Spacer(); Text(AppLocalization.string("AchievementView.6")).foregroundStyle(Palette.gold) }.font(.caption2).foregroundStyle(Palette.paper.opacity(0.65))
                        Rectangle().fill(Palette.paper.opacity(0.16)).frame(height: 1).padding(.top, 5)
                        if quest.cadence == .once {
                            Label(AppLocalization.string("AchievementView.7"), systemImage: "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(Palette.bright)
                            Text(AppLocalization.string("AchievementView.8"))
                                .font(.caption).foregroundStyle(Palette.paper.opacity(0.65))
                        } else {
                            HStack {
                                Text(AppLocalization.string("AchievementView.9")).font(.subheadline.bold()); Spacer()
                                Text("\(progress.count)").font(.system(size: 29, weight: .black, design: .rounded)) + Text(AppLocalization.format("AchievementView.10", AppLocalization.argument(progress.target))).font(.caption)
                            }
                            ProgressView(value: min(Double(progress.count) / Double(progress.target), 1)).tint(Palette.bright)
                            Text(progress.achieved ? AppLocalization.string("AchievementView.11") : AppLocalization.string("AchievementView.12")).font(.caption2).foregroundStyle(Palette.paper.opacity(0.65))
                        }
                        if result.bonus > 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(title: "KEEP YOUR OWN RHYTHM", color: Palette.gold)
                                Text(AppLocalization.format("AchievementView.13", AppLocalization.argument(result.streak), AppLocalization.argument(result.completion.period.cadence == .week ? AppLocalization.string("period.weeks") : AppLocalization.string("period.months")), AppLocalization.argument(result.bonus))).font(.subheadline.bold()).foregroundStyle(Palette.gold)
                                Text(AppLocalization.format("AchievementView.14", AppLocalization.argument(result.completion.period.cadence == .week ? AppLocalization.string("period.weeks") : AppLocalization.string("period.months")))).font(.caption2)
                            }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Palette.gold.opacity(0.09))
                        }
                        PrimaryButton(title: AppLocalization.string("AchievementView.15"), dark: true) { dismiss() }.accessibilityIdentifier("achievement.done").padding(.top, 8)
                        Button(AppLocalization.string("AchievementView.16")) {
                            do { try store.transact { try $0.undo(completionID: result.completion.id) }; dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.font(.caption).underline().foregroundStyle(Palette.paper.opacity(0.7)).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("achievement.undo")
                    }.padding(24)
                }
            }
        }.background(Palette.ink).foregroundStyle(Palette.paper)
            .preferredColorScheme(.dark)
            .modifier(ErrorNotice(error: $error))
            .sheet(isPresented: $showChallenge) { ChallengePaywall(store: store, isPresented: $showChallenge) }
            .task {
                reachedCap = !ChallengeNoticeStore().newlyReached(before: result.before, after: result.after).isEmpty
                if store.engine.preferences.usesSimplifiedEffects(systemReduceMotion: reduceMotion) { artVisible = true; rewardsVisible = true; growth = 1; return }
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
            if result.completion.rewards.total == 0 { Text(AppLocalization.string("AchievementView.17")).font(.subheadline.bold()).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.teal) }
        }.padding(.top, 4)
    }
}
