import Foundation
import PentaphorCore

enum AppLocalization {
    static var current: LocalizedText {
        text(preferredLanguages: Bundle.main.preferredLocalizations, locale: .current)
    }
    static func text(preferredLanguages: [String], locale: Locale) -> LocalizedText {
        LocalizedText(bundle: .main, preferredLanguages: preferredLanguages, locale: locale)
    }
    static func string(_ key: String) -> String { current.string(key) }
    static func format(_ key: String, _ arguments: String...) -> String {
        String(format: current.string(key), locale: current.locale, arguments: arguments)
    }
    static func argument(_ value: String) -> String { value }
    static func argument(_ value: Int) -> String { value.formatted(.number.locale(.current)) }
}
