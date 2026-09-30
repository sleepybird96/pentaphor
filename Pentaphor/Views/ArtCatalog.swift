import Foundation
import PentaphorCore

struct Art: Decodable, Identifiable, Sendable {
    let id: String
    let label: String
    let file: String
    let category: String
    let keywords: String
    func displayLabel(using text: LocalizedText) -> String { text.string("art.\(id).label") }
    func displayCategory(using text: LocalizedText) -> String { text.string("category.\(category)") }
    func matches(_ query: String, using text: LocalizedText) -> Bool {
        let terms = [label, keywords, category, id, displayLabel(using: text), displayCategory(using: text), text.string("art.\(id).keywords")]
        return query.isEmpty || terms.joined(separator: " ").localizedCaseInsensitiveContains(query)
    }
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

