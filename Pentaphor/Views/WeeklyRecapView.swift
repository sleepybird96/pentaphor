import SwiftUI
import PentaphorCore

struct WeeklyRecapView: View {
    @Environment(ChallengePurchaseService.self) private var purchases
    let recap: WeeklyRecap
    let timeZoneID: String
    let simplifiedEffects: Bool
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStage = 0
    @State private var growth = 0.0

    init(recap: WeeklyRecap, timeZoneID: String, simplifiedEffects: Bool, onDone: @escaping () -> Void) {
        self.recap = recap
        self.timeZoneID = timeZoneID
        self.simplifiedEffects = simplifiedEffects
        self.onDone = onDone
    }

    private var settledEffects: Bool { simplifiedEffects || reduceMotion }
    private var positiveStats: [Stat] { Stat.allCases.filter { recap.gains[$0] > 0 } }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        let start = formatter.string(from: recap.period.start)
        // The period end is exclusive; its final second is always in the closing day,
        // including weeks that cross a daylight-saving transition.
        let end = formatter.string(from: recap.period.end.addingTimeInterval(-1))
        return "\(start) — \(end)"
    }

    var body: some View {
        VStack(spacing: 0) {
            BrandBar(dark: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 18) {
                        actionSummary
                            .opacity(isVisible(1) ? 1 : 0)
                            .offset(y: isVisible(1) ? 0 : 12)
                        gains
                            .opacity(isVisible(2) ? 1 : 0)
                            .offset(y: isVisible(2) ? 0 : 12)
                        activities
                            .opacity(isVisible(3) ? 1 : 0)
                            .offset(x: isVisible(3) ? 0 : 18)
                    }.padding(.horizontal, 24).padding(.vertical, 16)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(title: AppLocalization.string("WeeklyRecapView.2"), dark: true, action: onDone)
                    .accessibilityIdentifier("recap.done")
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
                    .background(Palette.ink)
            }
        }
        .background(Palette.ink)
        .foregroundStyle(Palette.paper)
        .preferredColorScheme(.dark)
        .task(id: settledEffects) { await reveal() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(title: "YOUR WEEK. YOUR PROGRESS.", color: Palette.gold)
            Text("WEEK COMPLETE")
                .font(.custom("AvenirNextCondensed-HeavyItalic", size: 42, relativeTo: .largeTitle))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(Palette.bright)
                .shadow(color: Palette.teal, radius: 0, x: 3, y: 3)
                .rotationEffect(.degrees(-3), anchor: .leading)
                .padding(.vertical, 2)
                .accessibilityLabel("WEEK COMPLETE")
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recap.title")
            Text(dateRange)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.paper.opacity(0.75))
                .accessibilityIdentifier("recap.period")
            Text(AppLocalization.string("WeeklyRecapView.3"))
                .font(.subheadline.weight(.heavy))
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .trailing) {
                Palette.art
                Rectangle().fill(Palette.teal.opacity(0.18))
                    .frame(width: 76).rotationEffect(.degrees(17)).offset(x: 42)
            }.clipped()
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.bright).frame(height: 3)
        }
    }

    private var actionSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                actionCount
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) { summaryDetails }
            }
            VStack(alignment: .leading, spacing: 6) {
                actionCount
                VStack(alignment: .leading, spacing: 6) { summaryDetails }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.format("WeeklyRecapView.4", AppLocalization.argument(recap.completionCount), AppLocalization.argument(recap.questCount), AppLocalization.argument(recap.weeklyGoalsAchieved)))
        .accessibilityIdentifier("recap.actions")
    }

    private var actionCount: some View {
        Text(AppLocalization.current.format("recap.actions", recap.completionCount))
            .font(.custom("AvenirNextCondensed-HeavyItalic", size: 42, relativeTo: .largeTitle))
            .foregroundStyle(Palette.paper)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var summaryDetails: some View {
        Text(AppLocalization.format("WeeklyRecapView.6", AppLocalization.argument(recap.questCount)))
            .font(.subheadline.bold()).foregroundStyle(Palette.bright)
        if recap.weeklyGoalsAchieved > 0 {
            Label(AppLocalization.format("WeeklyRecapView.7", AppLocalization.argument(recap.weeklyGoalsAchieved)), systemImage: "checkmark.seal.fill")
                .font(.caption.bold()).foregroundStyle(Palette.gold)
        }
    }

    private var activities: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(title: "THE MOVES YOU MADE", color: Palette.paper.opacity(0.6))
            ForEach(recap.activities) { activity in
                HStack(spacing: 14) {
                    QuestArt(id: activity.artID, pixelSize: 240)
                        .frame(width: 70, height: 70)
                        .background(Palette.art, in: CutCorner())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(activity.name).font(.headline.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
                        Text(activity.cadence.korean)
                            .font(.caption2.bold()).foregroundStyle(Palette.paper.opacity(0.6))
                    }
                    Spacer(minLength: 4)
                    Text(AppLocalization.current.format("recap.times", activity.count))
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.bright)
                        .fixedSize()
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AppLocalization.format("WeeklyRecapView.9", AppLocalization.argument(activity.name), AppLocalization.argument(activity.count)))
            }
        }
    }

    private var gains: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Palette.paper.opacity(0.16)).frame(height: 1)
            Eyebrow(title: "YOUR GROWTH", color: Palette.gold)
                .accessibilityLabel(AppLocalization.string("WeeklyRecapView.10"))
                .accessibilityAddTraits(.isHeader)
            ParameterRadar(before: recap.before, after: recap.after,
                           progress: settledEffects ? 1 : growth, simplifiedEffects: settledEffects)
            if purchases.entitlement.access == .free && Stat.allCases.contains(where: { recap.after[$0] > 99 }) {
                Text(AppLocalization.string("WeeklyRecapView.11")).font(.caption).foregroundStyle(Palette.gold)
            }
            HStack {
                Text(AppLocalization.string("WeeklyRecapView.12"))
                Spacer()
                Text(AppLocalization.string("WeeklyRecapView.13")).foregroundStyle(Palette.gold)
            }.font(.caption2).foregroundStyle(Palette.paper.opacity(0.65))

            VStack(alignment: .leading, spacing: 0) {
                if positiveStats.isEmpty {
                    Text(AppLocalization.string("WeeklyRecapView.14"))
                        .font(.subheadline.bold())
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.teal, in: CutCorner())
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(positiveStats) { stat in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(stat.title).font(.subheadline.bold())
                                Spacer(minLength: 0)
                                Text("+\(recap.gains[stat])")
                                    .font(.system(.title2, design: .rounded, weight: .heavy))
                                    .minimumScaleFactor(0.65)
                            }
                            .padding(14)
                            .foregroundStyle(Palette.ink)
                            .background(stat == .perseverance ? Palette.gold : Palette.paper, in: CutCorner())
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(positiveStats.isEmpty ? AppLocalization.string("WeeklyRecapView.15") : positiveStats.map { "\($0.title) +\(recap.gains[$0])" }.joined(separator: ", "))
            .accessibilityIdentifier("recap.gains")

            if recap.streakBonus > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title: "KEEP YOUR OWN RHYTHM", color: Palette.gold)
                    Text(AppLocalization.format("WeeklyRecapView.16", AppLocalization.argument(recap.streakBonus)))
                        .font(.subheadline.bold()).foregroundStyle(Palette.gold)
                    Text(AppLocalization.string("WeeklyRecapView.17"))
                        .font(.caption).foregroundStyle(Palette.paper.opacity(0.75))
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.gold.opacity(0.09), in: CutCorner())
                .accessibilityIdentifier("recap.bonus")
            }
        }
    }

    private func isVisible(_ stage: Int) -> Bool { settledEffects || revealStage >= stage }

    @MainActor
    private func reveal() async {
        guard !Task.isCancelled else { return }
        if settledEffects {
            revealStage = 3
            growth = 1
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { revealStage = 1 }
        do {
            try await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { revealStage = 2 }
            try await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { revealStage = 3 }
            try await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 1.1)) { growth = 1 }
        } catch {
            // SwiftUI cancels this task when the recap closes or motion settings change.
            return
        }
    }
}
