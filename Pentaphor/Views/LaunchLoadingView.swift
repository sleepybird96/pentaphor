import SwiftUI
import PentaphorCore

struct LaunchLoadingView: View {
    let onCycleComplete: () -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var cycle = LaunchGrowthCycle(seed: UInt64.random(in: .min ... .max))
    @State private var cycleStart = Date.now
    @State private var isPlaying = false

    private enum Playback: Hashable { case paused, still, animated }
    private var playback: Playback {
        scenePhase != .active ? .paused : reduceMotion ? .still : .animated
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 28)
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image("BrandIcon").resizable().scaledToFit().frame(width: 43, height: 43).accessibilityHidden(true)
                        Text("PENTAPHOR")
                            .font(.custom("AvenirNextCondensed-HeavyItalic", size: 37, relativeTo: .largeTitle))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Text(BrandCopy.slogan)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(2)
                        .foregroundStyle(Palette.bright).padding(.top, 19)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .offset(y: 32)
                Spacer(minLength: 30)
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: playback != .animated)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(cycleStart))
                    let radii = reduceMotion ? [0.48, 0.48, 0.48, 0.48, 0.48] : cycle.radii(progress: isPlaying ? elapsed / 1.2 : 0)
                    LaunchPolygonArtwork(radii: radii)
                }
                .frame(width: min(proxy.size.width - 48, 340), height: min(proxy.size.width - 48, 340))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("기록을 불러오는 중")
                .accessibilityValue(reduceMotion ? "간소한 연출" : "성장 연출")
                .accessibilityIdentifier("launch.animation")
                Spacer(minLength: 30)
                Text(BrandCopy.tagline).font(.subheadline).foregroundStyle(Palette.paper.opacity(0.65))
                    .multilineTextAlignment(.center).padding(.bottom, 36)
            }
            .padding(.horizontal, 24).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Palette.paper).background(Palette.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain).accessibilityIdentifier("launch.presentation")
        .task(id: playback) {
            guard playback != .paused else { return }
            // A resumed, interrupted launch shows a whole cycle. Completed launches
            // remove this view entirely and do not restart on foregrounding.
            isPlaying = playback == .animated
            cycleStart = .now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(playback == .still ? 0.2 : 1.2)) }
                catch { return }
                guard !Task.isCancelled else { return }
                if onCycleComplete() { return }
                if playback == .animated {
                    cycle = LaunchGrowthCycle(seed: UInt64.random(in: .min ... .max), startingRadii: cycle.radii(progress: 1))
                }
                cycleStart = .now
            }
        }
    }
}

private struct LaunchPolygonArtwork: View {
    let radii: [Double]
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.44
            func point(_ index: Int, _ scale: Double) -> CGPoint {
                let angle = Double(index) * .pi * 2 / 5 - .pi / 2
                return CGPoint(x: center.x + cos(angle) * radius * scale, y: center.y + sin(angle) * radius * scale)
            }
            func polygon(_ values: [Double]) -> Path {
                var path = Path()
                path.addLines((0..<5).map { point($0, values[$0]) })
                path.closeSubpath()
                return path
            }
            for level in [0.33, 0.66, 1.0] {
                context.stroke(polygon(Array(repeating: level, count: 5)), with: .color(Palette.paper.opacity(0.1)), lineWidth: 1)
            }
            var axes = Path()
            for index in 0..<5 { axes.move(to: center); axes.addLine(to: point(index, 1)) }
            context.stroke(axes, with: .color(Palette.paper.opacity(0.06)), lineWidth: 1)
            let shape = polygon(radii)
            context.fill(shape, with: .linearGradient(Gradient(colors: [Palette.bright.opacity(0.42), Palette.teal.opacity(0.14)]),
                                                      startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            context.stroke(shape, with: .color(Palette.bright), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            for index in 0..<5 {
                let location = point(index, radii[index])
                let dot = Path(ellipseIn: CGRect(x: location.x - 4, y: location.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(Palette.paper))
            }
        }.accessibilityHidden(true)
    }
}
