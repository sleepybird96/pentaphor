import SwiftUI
import PentaphorCore

struct ChallengeUnlockView: View {
    let store: QuestStore
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var raw: StatPoints = .zero
    @State private var progress = 0.0
    @State private var released = false
    @State private var finished = false
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Eyebrow(title: "CHALLENGE UNLOCKED", color: Palette.bright)
            Text("성장의 한계를\n해금했어.").font(.system(size: 36, weight: .black)).multilineTextAlignment(.center)
            HStack(spacing: 25) {
                Text(released ? "∞" : "8").accessibilityLabel(released ? "퀘스트 무제한" : "퀘스트 8개")
                Text("/").opacity(0.3)
                Text(released ? "∞" : "99").accessibilityLabel(released ? "파라미터 무제한" : "파라미터 99")
            }.font(.system(size: 60, weight: .black, design: .rounded)).foregroundStyle(Palette.bright).contentTransition(.numericText())
            ParameterRadar(before: ChallengePolicy.displayed(raw, access: .free), after: raw, progress: progress,
                           simplifiedEffects: simplified, appliesChallengeLimit: false, unlockPulse: true)
            Text("지금까지 쌓인 성장, 앞으로 쌓아갈 성장까지.").font(.caption).foregroundStyle(Palette.paper.opacity(0.7))
            Spacer()
            PrimaryButton(title: "계속 쌓아가자", dark: true, action: onDone).disabled(!finished).accessibilityIdentifier("challenge.unlocked.done")
        }.padding(24).background(Palette.ink).foregroundStyle(Palette.paper).preferredColorScheme(.dark).interactiveDismissDisabled()
            .task {
                raw = store.engine.totals
                if store.engine.preferences.hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                if simplified { released = true; progress = 1; finished = true; return }
                try? await Task.sleep(for: .milliseconds(200)); guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { released = true }
                try? await Task.sleep(for: .milliseconds(200)); guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.55)) { progress = 1 }
                try? await Task.sleep(for: .milliseconds(800)); guard !Task.isCancelled else { return }
                finished = true
            }
            .onChange(of: store.replacementGeneration) { _, _ in onDone() }
    }
    private var simplified: Bool { store.engine.preferences.usesSimplifiedEffects(systemReduceMotion: reduceMotion) }
}
