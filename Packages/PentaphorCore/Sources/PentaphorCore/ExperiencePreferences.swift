import Foundation

public struct ExperiencePreferences: Codable, Equatable, Sendable {
    public var nickname = ""
    public var hasCompletedOnboarding = false
    public var hasCreatedFirstQuest = false
    public var hapticsEnabled = true
    public var simplifiedEffects = false

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
    public var errorDescription: String? { "닉네임은 줄바꿈 없이 20자 이내로 적어줘. 비워둬도 괜찮아." }
}
