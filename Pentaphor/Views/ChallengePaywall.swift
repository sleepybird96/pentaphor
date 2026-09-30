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
                    Text("99 너머의 성장을 해금해.").font(.title2.bold())
                    ParameterRadar(before: store.engine.totals, after: store.engine.totals)
                    comparison("진행 중 퀘스트", free: "8개")
                    comparison("각 파라미터 상한", free: "99")
                    Text("99 이후의 성장도 쌓이고 있어. 해금하면 모두 반영돼.").font(.subheadline).foregroundStyle(Palette.paper.opacity(0.8))
                    if purchases.entitlement.access == .unlocked {
                        Label("CHALLENGE 해금됨", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.bright)
                    } else if purchases.entitlement.access == nil {
                        Text(purchases.entitlement == .checking ? "구매 내역 확인 중" : "구매 내역을 확인하지 못했어").font(.subheadline)
                        Button("구매 내역 다시 확인") { Task { await purchases.refresh() } }
                    } else if let product = purchases.product {
                        PrimaryButton(title: "\(product.displayPrice) · 영구 해금", dark: true) { Task { await purchases.purchase() } }
                            .disabled(purchases.purchaseState == .purchasing || purchases.purchaseState == .restoring || purchases.purchaseState == .pending)
                            .accessibilityIdentifier("challenge.purchase")
                    } else {
                        Button("상품 다시 불러오기") { Task { await purchases.loadProduct(); await purchases.refresh() } }.accessibilityIdentifier("challenge.retry")
                    }
                    Text("한 번 구매하면, 계속 사용할 수 있어.").font(.caption)
                    if purchases.purchaseState == .pending { Text("구매 승인을 기다리고 있어. 승인되면 자동으로 해금돼.").font(.subheadline) }
                    if purchases.purchaseState == .purchasing || purchases.purchaseState == .restoring { ProgressView().tint(Palette.bright) }
                    if let message = purchases.lastError { Text(message).foregroundStyle(Palette.gold).font(.subheadline) }
                    if let message = purchases.restoreMessage { Text(message).foregroundStyle(Palette.bright).font(.subheadline) }
                    Button("구매 복원") { Task { await purchases.restore() } }.accessibilityIdentifier("challenge.restore")
                        .disabled(purchases.purchaseState == .purchasing || purchases.purchaseState == .restoring)
                    Link("이용약관", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    NavigationLink("개인정보 · 데이터 안내") { GuideDetailView(page: .about, timeZoneID: store.engine.state.timeZoneID) }
                }.padding(24)
            }.background(Palette.ink).foregroundStyle(Palette.paper)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { isPresented = false }.accessibilityIdentifier("challenge.close") } }
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
        HStack { Text(title).font(.headline); Spacer(); Text(free).foregroundStyle(Palette.paper.opacity(0.5)); Image(systemName: "arrow.right"); Text("∞").font(.system(size: 38, weight: .bold)).foregroundStyle(Palette.bright).accessibilityLabel("무제한") }
    }
}
