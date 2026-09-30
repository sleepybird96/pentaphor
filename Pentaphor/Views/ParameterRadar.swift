import SwiftUI
import PentaphorCore

private func radarPoint(index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
    let angle = Double(index) * .pi * 2 / 5 - .pi / 2
    return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
}

private struct RadarPolygon: Shape {
    let from: StatPoints
    let to: StatPoints
    var emphasizeGrowth = true
    var unlockPulse = false
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.5
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radii = unlockPulse ? ChallengeUnlockPresentation(raw: to).radii(progress: progress, simplified: !emphasizeGrowth) : RadarGrowth.radii(from: from, to: to, progress: progress, emphasizeGrowth: emphasizeGrowth)
        let points = radii.enumerated().map { index, normalized in
            radarPoint(index: index, radius: radius * normalized, center: center)
        }
        return Path { p in p.addLines(points); p.closeSubpath() }
    }
}

private struct RadarVertex: Shape {
    let from: StatPoints
    let to: StatPoints
    let index: Int
    let emphasizeGrowth: Bool
    var unlockPulse = false
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }

    func path(in rect: CGRect) -> Path {
        let changed = to[Stat.allCases[index]] > from[Stat.allCases[index]]
        let normalized = (unlockPulse ? ChallengeUnlockPresentation(raw: to).radii(progress: progress, simplified: !emphasizeGrowth) : RadarGrowth.radii(from: from, to: to, progress: progress, emphasizeGrowth: emphasizeGrowth))[index]
        let point = radarPoint(index: index, radius: min(rect.width, rect.height) * 0.5 * normalized,
                               center: CGPoint(x: rect.midX, y: rect.midY))
        let diameter: CGFloat = changed ? 7 : 4
        return Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter))
    }
}

private struct RegularPentagon: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.addLines((0..<5).map { radarPoint(index: $0, radius: min(rect.width, rect.height) / 2, center: CGPoint(x: rect.midX, y: rect.midY)) })
            p.closeSubpath()
        }
    }
}

struct ParameterRadar: View {
    let before: StatPoints
    let after: StatPoints
    var progress: Double = 1
    var dark = true
    var simplifiedEffects = false
    var appliesChallengeLimit = true
    var unlockPulse = false
    @Environment(ChallengePurchaseService.self) private var purchases
    private var shownBefore: StatPoints { appliesChallengeLimit ? ChallengePolicy.displayed(before, access: purchases.entitlement.access ?? .free) : before }
    private var shownAfter: StatPoints { appliesChallengeLimit ? ChallengePolicy.displayed(after, access: purchases.entitlement.access ?? .free) : after }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width - 104, proxy.size.height - 104)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                ForEach(1...4, id: \.self) { level in
                    RegularPentagon().stroke((dark ? Palette.paper : Palette.ink).opacity(0.16), lineWidth: 0.8)
                        .frame(width: size * Double(level) / 4, height: size * Double(level) / 4).position(center)
                }
                Path { p in
                    for index in 0..<5 { p.move(to: center); p.addLine(to: radarPoint(index: index, radius: size / 2, center: center)) }
                }.stroke((dark ? Palette.paper : Palette.ink).opacity(0.12), lineWidth: 0.7)
                RadarPolygon(from: shownBefore, to: shownBefore, progress: 1)
                    .stroke((dark ? Palette.paper : Palette.ink).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(width: size, height: size).position(center)
                RadarPolygon(from: shownBefore, to: shownAfter, emphasizeGrowth: !(reduceMotion || simplifiedEffects), unlockPulse: unlockPulse, progress: progress)
                    .fill(Palette.teal.opacity(0.48)).frame(width: size, height: size).position(center)
                RadarPolygon(from: shownBefore, to: shownAfter, emphasizeGrowth: !(reduceMotion || simplifiedEffects), unlockPulse: unlockPulse, progress: progress)
                    .stroke(dark ? Palette.bright : Palette.teal, lineWidth: 2.3).frame(width: size, height: size).position(center)
                ForEach(Array(Stat.allCases.enumerated()), id: \.element.id) { index, stat in
                    let changed = shownAfter[stat] > shownBefore[stat]
                    RadarVertex(from: shownBefore, to: shownAfter, index: index, emphasizeGrowth: !(reduceMotion || simplifiedEffects), unlockPulse: unlockPulse, progress: progress)
                        .fill(changed ? Palette.gold : (dark ? Palette.paper : Palette.ink))
                        .frame(width: size, height: size).position(center)
                    VStack(spacing: 2) {
                        Text(stat.title).font(.caption.bold())
                        RadarNumber(from: shownBefore[stat], to: shownAfter[stat], progress: unlockPulse ? progress : 1).font(.system(.subheadline, design: .rounded, weight: .heavy))
                        if changed { Text("+\(shownAfter[stat] - shownBefore[stat])").font(.caption2.bold()) }
                    }.foregroundStyle(changed ? (dark ? Palette.gold : Palette.teal) : (dark ? Palette.paper : Palette.ink))
                        .position(radarPoint(index: index, radius: size / 2 + 25, center: center))
                }
            }
        }
        .frame(height: 276)
        .opacity(appliesChallengeLimit && purchases.entitlement.access == nil ? 0 : 1)
        .overlay {
            if appliesChallengeLimit && purchases.entitlement.access == nil {
                VStack {
                    Text(purchases.entitlement == .checking ? AppLocalization.string("ParameterRadar.1") : AppLocalization.string("ParameterRadar.2")).font(.caption)
                    if purchases.entitlement == .unavailable { Button(AppLocalization.string("ParameterRadar.3")) { Task { await purchases.refresh() } } }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appliesChallengeLimit && purchases.entitlement.access == nil ? AppLocalization.string("ParameterRadar.4") : AppLocalization.string("ParameterRadar.5") + Stat.allCases.map { "\($0.title) \(shownAfter[$0])" }.joined(separator: ", "))
    }
}

private struct RadarNumber: View, @preconcurrency Animatable {
    let from: Int
    let to: Int
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    var body: some View { Text("\(progress >= 1 ? to : from + Int(Double(to - from) * max(0, progress)))") }
}
