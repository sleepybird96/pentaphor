import Foundation

public enum Stat: String, Codable, CaseIterable, Identifiable, Sendable {
    case stamina, knowledge, perseverance, charm, courage
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .stamina: CoreLocalization.current.string("stat.stamina")
        case .knowledge: CoreLocalization.current.string("stat.knowledge")
        case .perseverance: CoreLocalization.current.string("stat.perseverance")
        case .charm: CoreLocalization.current.string("stat.charm")
        case .courage: CoreLocalization.current.string("stat.courage")
        }
    }
}

public struct StatPoints: Codable, Equatable, Sendable {
    public var stamina: Int
    public var knowledge: Int
    public var perseverance: Int
    public var charm: Int
    public var courage: Int
    public init(stamina: Int = 0, knowledge: Int = 0, perseverance: Int = 0, charm: Int = 0, courage: Int = 0) {
        self.stamina = stamina; self.knowledge = knowledge; self.perseverance = perseverance
        self.charm = charm; self.courage = courage
    }
    public static var zero: StatPoints { StatPoints() }
    public var total: Int { Stat.allCases.reduce(0) { $0 + self[$1] } }
    public subscript(_ stat: Stat) -> Int {
        get {
            switch stat {
            case .stamina: stamina
            case .knowledge: knowledge
            case .perseverance: perseverance
            case .charm: charm
            case .courage: courage
            }
        }
        set {
            switch stat {
            case .stamina: stamina = newValue
            case .knowledge: knowledge = newValue
            case .perseverance: perseverance = newValue
            case .charm: charm = newValue
            case .courage: courage = newValue
            }
        }
    }
    static func + (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        for stat in Stat.allCases { result[stat] += rhs[stat] }
        return result
    }
}

public struct TargetChange: Codable, Equatable, Sendable {
    public let effectiveFrom: Date
    public let target: Int
}

public struct Quest: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var artID: String
    public var cadence: Cadence
    public let createdAt: Date
    public var isArchived: Bool
    public var rewards: StatPoints
    public var targetChanges: [TargetChange]
    public var notes: String? = nil
    public var deletedAt: Date? = nil
    public var reminder: QuestReminder? = nil
}

public struct Completion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let questID: UUID
    public let recordedAt: Date
    public let period: PeriodWindow
    public let target: Int
    public let rewards: StatPoints
    public var isVoided: Bool
}

public struct AppState: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var timeZoneID: String
    public var quests: [Quest] = []
    public var completions: [Completion] = []
    public var weeklyRecapAcknowledgedThrough: Date? = nil
    public var preferences: ExperiencePreferences? = nil
    public init(timeZoneID: String) { self.timeZoneID = timeZoneID }
}

public struct QuestProgress: Sendable {
    public let period: PeriodWindow
    public let count: Int
    public let target: Int
    public var achieved: Bool { count >= target }
}

public struct StreakBonus: Identifiable, Sendable {
    public var id: String { questID.uuidString + "-" + String(period.start.timeIntervalSince1970) }
    public let questID: UUID
    public let period: PeriodWindow
    public let streak: Int
}

public struct CompletionResult: Sendable {
    public let completion: Completion
    public let before: StatPoints
    public let after: StatPoints
    public let bonus: Int
    public let streak: Int
}

public enum QuestError: Error, LocalizedError, Equatable {
    case invalidName, invalidArt, invalidTarget, invalidRewards, invalidReminder, notFound, archived
    case graceExpired, predatesQuest, cadenceLocked, duplicateRequest, alreadyCompleted, invalidState
    public var errorDescription: String? {
        switch self {
        case .invalidName: CoreLocalization.current.string("error.5")
        case .invalidArt: CoreLocalization.current.string("error.6")
        case .invalidTarget: CoreLocalization.current.string("error.7")
        case .invalidRewards: CoreLocalization.current.string("error.8")
        case .invalidReminder: CoreLocalization.current.string("error.9")
        case .notFound: CoreLocalization.current.string("error.10")
        case .archived: CoreLocalization.current.string("error.11")
        case .graceExpired: CoreLocalization.current.string("error.12")
        case .predatesQuest: CoreLocalization.current.string("error.13")
        case .alreadyCompleted: CoreLocalization.current.string("error.14")
        case .cadenceLocked: CoreLocalization.current.string("error.15")
        case .duplicateRequest: CoreLocalization.current.string("error.16")
        case .invalidState: CoreLocalization.current.string("error.17")
        }
    }
}
