import SwiftUI

enum BrandCopy {
    static let slogan = "STACK YOUR PROGRESS."
    static let tagline = "작은 행동을 쌓아, 나를 키우다."
}

struct ProgressHeadline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: -9) {
            Text("STACK YOUR").foregroundStyle(Palette.paper)
            Text("PROGRESS.").foregroundStyle(Palette.bright)
        }
        .font(.custom("AvenirNextCondensed-HeavyItalic", size: 51, relativeTo: .largeTitle))
        .minimumScaleFactor(0.65).lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BrandCopy.slogan)
    }
}
