import SwiftUI
import PentaphorCore

struct ChallengePaywall: View {
    let store: QuestStore
    @Binding var isPresented: Bool
    @Environment(ChallengePurchaseService.self) private var purchases
    @State private var unlock: ChallengeUnlockEvent?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Eyebrow(title: "BEYOND YOUR LIMITS", color: Palette.bright)
                    Text("CHALLENGE").font(.system(size: 39, weight: .black, design: .rounded)).minimumScaleFactor(0.6)
                    Text(AppLocalization.string("ChallengePaywall.1")).font(.title2.bold())
                    ParameterRadar(before: store.engine.totals, after: store.engine.totals)
                    comparison(AppLocalization.string("ChallengePaywall.2"), free: AppLocalization.string("ChallengePaywall.3"))
                    comparison(AppLocalization.string("ChallengePaywall.4"), free: "99")
                    Text(AppLocalization.string("ChallengePaywall.5")).font(.subheadline).foregroundStyle(Palette.paper.opacity(0.8))
                    if purchases.entitlement.access == .unlocked {
                        Label(AppLocalization.string("ChallengePaywall.6"), systemImage: "checkmark.seal.fill").foregroundStyle(Palette.bright)
                    } else if purchases.entitlement.access == nil {
                        Text(purchases.entitlement == .checking ? AppLocalization.string("ChallengePaywall.7") : AppLocalization.string("ChallengePaywall.8")).font(.subheadline)
                        Button(AppLocalization.string("ChallengePaywall.9")) { Task { await purchases.refresh() } }
                    } else if let product = purchases.product {
                        PrimaryButton(title: AppLocalization.format("ChallengePaywall.10", AppLocalization.argument(product.displayPrice)), dark: true) { Task { await purchases.purchase() } }
                            .disabled(purchases.purchaseState == .purchasing || purchases.purchaseState == .restoring || purchases.purchaseState == .pending)
                            .accessibilityIdentifier("challenge.purchase")
                    } else {
                        Button(AppLocalization.string("ChallengePaywall.11")) { Task { await purchases.loadProduct(); await purchases.refresh() } }.accessibilityIdentifier("challenge.retry")
                    }
                    Text(AppLocalization.string("ChallengePaywall.12")).font(.caption)
                    if purchases.purchaseState == .pending { Text(AppLocalization.string("ChallengePaywall.13")).font(.subheadline) }
                    if purchases.purchaseState == .purchasing || purchases.purchaseState == .restoring { ProgressView().tint(Palette.bright) }
                    if let message = purchases.lastError { Text(message).foregroundStyle(Palette.gold).font(.subheadline) }
                    if let message = purchases.restoreMessage { Text(message).foregroundStyle(Palette.bright).font(.subheadline) }
                    Button(AppLocalization.string("ChallengePaywall.14")) { Task { await purchases.restore() } }.accessibilityIdentifier("challenge.restore")
                        .disabled(purchases.purchaseState == .purchasing || purchases.purchaseState == .restoring)
                    Link(AppLocalization.string("ChallengePaywall.15"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    NavigationLink(AppLocalization.string("ChallengePaywall.16")) { GuideDetailView(page: .about, timeZoneID: store.engine.state.timeZoneID) }
                }.padding(24)
            }.background(Palette.ink).foregroundStyle(Palette.paper)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(AppLocalization.string("ChallengePaywall.17")) { isPresented = false }.accessibilityIdentifier("challenge.close") } }
                .task { await purchases.loadProduct(); presentUnlock() }
                .onChange(of: purchases.unlockEvents) { _, _ in presentUnlock() }
                .fullScreenCover(item: $unlock, onDismiss: { isPresented = false }) { _ in
                    ChallengeUnlockView(store: store) { unlock = nil }
                }
        }.tint(Palette.bright).preferredColorScheme(.dark)
    }
    private func presentUnlock() {
        guard unlock == nil, let event = purchases.unlockEvents.first else { return }
        purchases.consumeUnlock(event.id); unlock = event
    }
    private func comparison(_ title: String, free: String) -> some View {
        HStack { Text(title).font(.headline); Spacer(); Text(free).foregroundStyle(Palette.paper.opacity(0.5)); Image(systemName: "arrow.right"); Text("∞").font(.system(size: 38, weight: .bold)).foregroundStyle(Palette.bright).accessibilityLabel(AppLocalization.string("ChallengePaywall.18")) }
    }
}
