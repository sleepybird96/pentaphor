import Foundation

public struct ExperiencePreferences: Codable, Equatable, Sendable {
    public var nickname = ""
    public var hasCompletedOnboarding = false
    public var hasCreatedFirstQuest = false
    public var hapticsEnabled = true
    public var simplifiedEffects = false

    // Missing in older saved preferences: preserve their existing reminder behavior.
    private var remindersEnabledOverride: Bool?
    public var remindersEnabled: Bool {
        get { remindersEnabledOverride ?? true }
        set { remindersEnabledOverride = newValue }
    }

    public init() {}

    // A missing field belongs to a user who already used the app before onboarding existed.
    public static var establishedUser: Self {
        var value = Self()
        value.hasCompletedOnboarding = true
        value.hasCreatedFirstQuest = true
        return value
    }

    public func usesSimplifiedEffects(systemReduceMotion: Bool) -> Bool {
        systemReduceMotion || simplifiedEffects
    }
}

public enum PreferencesError: Error, LocalizedError, Equatable {
    case invalidNickname
    public var errorDescription: String? { CoreLocalization.current.string("error.18") }
}
