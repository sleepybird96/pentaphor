import Foundation

/// Text language and regional formatting are deliberately independent.
public struct LocalizedText: Sendable {
    private let bundle: Bundle
    public let language: String
    public let locale: Locale

    public init(bundle: Bundle, preferredLanguages: [String], locale: Locale) {
        language = Bundle.preferredLocalizations(from: ["en", "ko"], forPreferences: preferredLanguages).first ?? "en"
        self.locale = locale
        self.bundle = bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
    }
    public func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        // Foundation uses this locale for plural rules too. Match the text's
        // language while retaining the user's region and locale extensions.
        var components = Locale.Components(locale: locale)
        components.languageComponents.languageCode = Locale.LanguageCode(language)
        return String(format: string(key), locale: Locale(components: components), arguments: arguments)
    }
}

public enum CoreLocalization {
    public static var current: LocalizedText {
        text(preferredLanguages: Bundle.main.preferredLocalizations, locale: .current)
    }
    public static func text(preferredLanguages: [String], locale: Locale) -> LocalizedText {
        LocalizedText(bundle: .module, preferredLanguages: preferredLanguages, locale: locale)
    }
}
