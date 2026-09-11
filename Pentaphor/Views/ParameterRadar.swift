import SwiftUI
import PentaphorCore

private func radarPoint(index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
    let angle = Double(index) * .pi * 2 / 5 - .pi / 2
    return CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
}

private struct RadarPolygon: Shape {
    let from: StatPoints
    let to: StatPoints
    let maximum: Double
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.5
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = Stat.allCases.enumerated().map { index, stat in
            let value = Double(from[stat]) + Double(to[stat] - from[stat]) * progress
            let normalized = 0.15 + 0.78 * sqrt(max(0, value) / max(1, maximum))
            return radarPoint(index: index, radius: radius * normalized, center: center)
        }
        return Path { p in p.addLines(points); p.closeSubpath() }
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
    private var maximum: Double { Double(max(5, Stat.allCases.map { max(before[$0], after[$0]) }.max() ?? 5)) }

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
                RadarPolygon(from: before, to: before, maximum: maximum, progress: 1)
                    .stroke((dark ? Palette.paper : Palette.ink).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(width: size, height: size).position(center)
                RadarPolygon(from: before, to: after, maximum: maximum, progress: progress)
                    .fill(Palette.teal.opacity(0.48)).frame(width: size, height: size).position(center)
                RadarPolygon(from: before, to: after, maximum: maximum, progress: progress)
                    .stroke(dark ? Palette.bright : Palette.teal, lineWidth: 2.3).frame(width: size, height: size).position(center)
                ForEach(Array(Stat.allCases.enumerated()), id: \.element.id) { index, stat in
                    let changed = after[stat] > before[stat]
                    let value = Double(before[stat]) + Double(after[stat] - before[stat]) * progress
                    let radius = size / 2 * (0.15 + 0.78 * sqrt(max(0, value) / maximum))
                    Circle().fill(changed ? Palette.gold : (dark ? Palette.paper : Palette.ink)).frame(width: changed ? 7 : 4, height: changed ? 7 : 4)
                        .position(radarPoint(index: index, radius: radius, center: center))
                    VStack(spacing: 2) {
                        Text(stat.title).font(.caption.bold())
                        Text("\(after[stat])").font(.system(.subheadline, design: .rounded, weight: .heavy))
                        if changed { Text("+\(after[stat] - before[stat])").font(.caption2.bold()) }
                    }.foregroundStyle(changed ? (dark ? Palette.gold : Palette.teal) : (dark ? Palette.paper : Palette.ink))
                        .position(radarPoint(index: index, radius: size / 2 + 25, center: center))
                }
            }
        }
        .frame(height: 276)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("파라미터: " + Stat.allCases.map { "\($0.title) \(after[$0])" }.joined(separator: ", "))
    }
}
