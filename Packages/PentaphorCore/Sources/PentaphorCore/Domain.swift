import Foundation

public enum Stat: String, Codable, CaseIterable, Identifiable, Sendable {
    case stamina, knowledge, perseverance, charm, courage
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .stamina: "체력"
        case .knowledge: "지식"
        case .perseverance: "끈기"
        case .charm: "매력"
        case .courage: "용기"
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
        case .invalidName: "퀘스트 이름을 1~40자로 적어줘."
        case .invalidArt: "퀘스트 아트를 골라줘."
        case .invalidTarget: "목표는 1~99회로 정해줘."
        case .invalidRewards: "포인트는 음수 없이 최대 2까지 나눠줘."
        case .invalidReminder: "알림 요일과 시간을 확인해줘."
        case .notFound: "이 기록을 찾지 못했어."
        case .archived: "보관한 퀘스트야. 먼저 복원해줘."
        case .graceExpired: "지난주 기록은 월요일 오전 9시 전까지만 가능해."
        case .predatesQuest: "퀘스트를 만들기 전 기간에는 기록할 수 없어."
        case .alreadyCompleted: "이미 완료한 퀘스트야. 기록을 되돌리면 다시 완료할 수 있어."
        case .cadenceLocked: "기록이 있는 퀘스트는 주기를 바꿀 수 없어. 새 퀘스트로 만들어줘."
        case .duplicateRequest: "이미 처리한 기록 요청이야."
        case .invalidState: "저장된 기록을 읽을 수 없어. 원본은 그대로 보관했어."
        }
    }
}
