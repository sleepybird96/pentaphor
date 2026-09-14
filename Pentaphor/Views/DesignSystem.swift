import SwiftUI
import PentaphorCore
import ImageIO

enum Palette {
    static let ink = Color(red: 20/255, green: 32/255, blue: 28/255)
    static let paper = Color(red: 240/255, green: 237/255, blue: 223/255)
    static let teal = Color(red: 8/255, green: 126/255, blue: 121/255)
    static let bright = Color(red: 53/255, green: 214/255, blue: 190/255)
    static let gold = Color(red: 228/255, green: 188/255, blue: 101/255)
    static let muted = Color(red: 91/255, green: 107/255, blue: 97/255)
    static let art = Color(red: 14/255, green: 23/255, blue: 19/255)
}

struct Art: Decodable, Identifiable, Sendable {
    let id: String
    let label: String
    let file: String
    let category: String
    let keywords: String
}

enum ArtCatalog {
    static let all: [Art] = {
        guard let url = Bundle.main.url(forResource: "art-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Art].self, from: data) else {
            preconditionFailure("The bundled art catalog is missing or invalid.")
        }
        return entries
    }()
    static func art(_ id: String) -> Art { all.first { $0.id == id } ?? all[0] }
    static var categories: [String] { all.reduce(into: []) { if !$0.contains($1.category) { $0.append($1.category) } } }
}

@MainActor
private enum ArtImageCache {
    static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    static func image(id: String, pixelSize: Int) -> UIImage? {
        let key = "\(id)-\(pixelSize)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        let art = ArtCatalog.art(id)
        guard let url = Bundle.main.url(forResource: art.file, withExtension: nil),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: pixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        images.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}

struct QuestArt: View {
    let id: String
    var pixelSize = 900
    var body: some View {
        if let image = ArtImageCache.image(id: id, pixelSize: pixelSize) {
            Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

struct BrandBar: View {
    var dark = false
    var onSettings: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 9) {
            Image("BrandIcon").resizable().scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text("PENTAPHOR").font(.custom("AvenirNextCondensed-HeavyItalic", size: 26, relativeTo: .title2))
            Spacer()
            if let onSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("설정").accessibilityIdentifier("settings.open")
            } else {
                Text("STACK YOUR\nPROGRESS.").font(.system(size: 8, weight: .heavy, design: .monospaced)).tracking(1)
                    .multilineTextAlignment(.trailing).accessibilityLabel(BrandCopy.slogan)
            }
        }
        .foregroundStyle(dark ? Palette.paper : Palette.ink)
        .padding(.horizontal, 24).padding(.vertical, onSettings == nil ? 17 : 10)
        .overlay(alignment: .bottom) { Rectangle().fill((dark ? Palette.paper : Palette.ink).opacity(0.15)).frame(height: 1) }
    }
}

struct Eyebrow: View {
    let title: String
    var color: Color = Palette.teal
    var body: some View { Text(title).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(color) }
}

struct CutCorner: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 5, y: 0)); p.addLine(to: CGPoint(x: rect.width, y: 0))
            p.addLine(to: CGPoint(x: rect.width - 5, y: rect.height)); p.addLine(to: CGPoint(x: 0, y: rect.height)); p.closeSubpath()
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var dark = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title).font(.system(.body, weight: .heavy)); Spacer(); Image(systemName: "arrow.up.right").font(.title2.bold()).foregroundStyle(dark ? Palette.teal : Palette.bright) }
                .padding(18).foregroundStyle(dark ? Palette.ink : Palette.paper)
                .background(dark ? Palette.paper : Palette.ink, in: CutCorner())
        }.buttonStyle(.plain)
    }
}

extension Cadence {
    var korean: String { self == .week ? "매주" : "매월" }
    var periodLabel: String { self == .week ? "이번 주" : "이번 달" }
}

struct ErrorNotice: ViewModifier {
    @Binding var error: String?
    func body(content: Content) -> some View {
        content.alert("저장하지 못했어", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("확인") { error = nil }
        } message: { Text(error ?? "") }
    }
}
