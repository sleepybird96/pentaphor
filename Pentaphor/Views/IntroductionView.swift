import SwiftUI
import PentaphorCore

struct IntroductionView: View {
    let store: QuestStore
    var isReplay = false
    let onFinish: (_ createQuest: Bool) -> Void
    @State private var step = 0
    @State private var nickname = ""
    @State private var error: String?
    @FocusState private var editingNickname: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("BrandIcon").resizable().scaledToFit().frame(width: 31, height: 31).accessibilityHidden(true)
                Text("PENTAPHOR").font(.custom("AvenirNextCondensed-HeavyItalic", size: 24, relativeTo: .title2))
                Spacer()
                Button(isReplay ? AppLocalization.string("IntroductionView.1") : AppLocalization.string("IntroductionView.2")) { finish(createQuest: false) }
                    .font(.subheadline).frame(minWidth: 60, minHeight: 44)
                    .accessibilityIdentifier("onboarding.skip")
            }.padding(.horizontal, 24).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Eyebrow(title: isReplay ? "QUICK GUIDE" : "0\(step + 1) / 03", color: Palette.gold)
                    switch step {
                    case 1: nicknamePage
                    case 2: explanationPage
                    default: welcomePage
                    }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).id(step)
        }
        .background(Palette.ink).foregroundStyle(Palette.paper)
        .preferredColorScheme(.dark)
        .modifier(ErrorNotice(error: $error))
        .interactiveDismissDisabled(!isReplay)
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProgressHeadline()
            Text(BrandCopy.tagline).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
            IntroductionGrowthPreview(simplifiedEffects: store.engine.preferences.simplifiedEffects)
            PrimaryButton(title: isReplay ? AppLocalization.string("IntroductionView.3") : AppLocalization.string("IntroductionView.4"), dark: true) {
                step = isReplay ? 2 : 1
            }.accessibilityIdentifier("onboarding.start")
        }
    }

    private var nicknamePage: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(AppLocalization.string("IntroductionView.5")).font(.system(size: 39, weight: .black)).fixedSize(horizontal: false, vertical: true)
            Text(AppLocalization.string("IntroductionView.6"))
                .font(.body).lineSpacing(5).foregroundStyle(Palette.paper.opacity(0.75))
            Image("BrandIcon").resizable().scaledToFit().frame(width: 96, height: 96).padding(.vertical, 12).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                TextField(AppLocalization.string("IntroductionView.7"), text: $nickname)
                    .font(.title2.bold()).padding(.vertical, 12)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($editingNickname).submitLabel(.done).onSubmit { editingNickname = false }
                    .accessibilityIdentifier("onboarding.nickname")
                Rectangle().fill(Palette.bright).frame(height: 2)
                HStack {
                    Text(AppLocalization.string("IntroductionView.8"))
                    Spacer()
                    Text("\(nickname.trimmingCharacters(in: .whitespacesAndNewlines).count) / 20")
                }.font(.caption).foregroundStyle(Palette.paper.opacity(0.65))
            }
            PrimaryButton(title: AppLocalization.string("IntroductionView.9"), dark: true) {
                editingNickname = false
                if validNickname { step = 2 } else { error = PreferencesError.invalidNickname.localizedDescription }
            }.accessibilityIdentifier("onboarding.next")
            Button(AppLocalization.string("IntroductionView.10")) { nickname = ""; editingNickname = false; step = 2 }
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("onboarding.no-name")
        }
    }

    private var explanationPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(AppLocalization.string("IntroductionView.11")).font(.system(size: 35, weight: .black)).fixedSize(horizontal: false, vertical: true)
            guideRow(number: "01", title: AppLocalization.string("IntroductionView.12"), detail: AppLocalization.string("IntroductionView.13"))
            guideRow(number: "02", title: AppLocalization.string("IntroductionView.14"), detail: AppLocalization.string("IntroductionView.15"))
            guideRow(number: "03", title: AppLocalization.string("IntroductionView.16"), detail: AppLocalization.string("IntroductionView.17"))
            Text(AppLocalization.string("IntroductionView.18"))
                .font(.caption).foregroundStyle(Palette.paper.opacity(0.7)).lineSpacing(4)
            if isReplay {
                PrimaryButton(title: AppLocalization.string("IntroductionView.19"), dark: true) { onFinish(false) }
                    .accessibilityIdentifier("onboarding.done")
            } else {
                PrimaryButton(title: AppLocalization.string("IntroductionView.20"), dark: true) { finish(createQuest: true) }
                    .accessibilityIdentifier("onboarding.create")
                Button(AppLocalization.string("IntroductionView.21")) { finish(createQuest: false) }
                    .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("onboarding.explore")
            }
        }
    }

    private func guideRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.system(.title2, design: .monospaced, weight: .black)).foregroundStyle(Palette.bright)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).lineSpacing(4).foregroundStyle(Palette.paper.opacity(0.75))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(17).background(Palette.paper.opacity(0.045))
    }

    private var validNickname: Bool {
        let value = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.count <= 20 && value.rangeOfCharacter(from: .newlines) == nil
    }

    private func finish(createQuest: Bool) {
        guard !isReplay else { onFinish(false); return }
        do {
            var preferences = store.engine.preferences
            preferences.nickname = nickname
            preferences.hasCompletedOnboarding = true
            try store.transact { try $0.updatePreferences(preferences) }
            onFinish(createQuest)
        } catch { self.error = error.localizedDescription }
    }
}

private struct IntroductionGrowthPreview: View {
    let simplifiedEffects: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    private let before = StatPoints(stamina: 25, knowledge: 40, perseverance: 15, charm: 10, courage: 25)
    private let after = StatPoints(stamina: 27, knowledge: 40, perseverance: 15, charm: 10, courage: 25)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                QuestArt(id: "running", pixelSize: 240).frame(width: 58, height: 58)
                Text(AppLocalization.string("IntroductionView.22")).font(.subheadline.bold())
                Spacer()
                Text(AppLocalization.string("IntroductionView.23")).font(.headline).foregroundStyle(Palette.bright)
            }.padding(.horizontal, 16).padding(.top, 10)
            ParameterRadar(before: before, after: after, progress: progress, simplifiedEffects: simplifiedEffects)
            Text(AppLocalization.string("IntroductionView.24"))
                .font(.caption2).foregroundStyle(Palette.paper.opacity(0.65)).padding(.bottom, 16)
        }.background(Palette.art)
            .task {
                if reduceMotion || simplifiedEffects { progress = 1; return }
                withAnimation(.linear(duration: 0.95)) { progress = 1 }
            }
    }
}
