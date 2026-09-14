import Foundation
import Observation

@MainActor @Observable public final class QuestStore {
    public private(set) var engine: QuestEngine
    private let repository: any StateRepository
    public init(repository: any StateRepository, timeZoneID: String = TimeZone.current.identifier) throws {
        self.repository = repository
        if let saved = try repository.load() {
            self.engine = QuestEngine(state: saved)
        } else {
            var initial = AppState(timeZoneID: timeZoneID)
            initial.preferences = ExperiencePreferences()
            try repository.save(initial)
            self.engine = QuestEngine(state: initial)
        }
    }
    @discardableResult
    public func transact<T>(_ mutation: (inout QuestEngine) throws -> T) throws -> T {
        var candidate = engine
        let result = try mutation(&candidate)
        try repository.save(candidate.state)
        engine = candidate
        return result
    }
}
