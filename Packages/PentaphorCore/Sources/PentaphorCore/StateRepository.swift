import Foundation
import SwiftData

@MainActor public protocol StateRepository {
    func load() throws -> AppState?
    func save(_ state: AppState) throws
}

@Model final class StateDocument {
    @Attribute(.unique) var key: String
    var payload: Data
    init(payload: Data) { self.key = "pentaphor-state"; self.payload = payload }
}

@MainActor public final class SwiftDataStateRepository: StateRepository {
    private let container: ModelContainer
    private let context: ModelContext

    public init(inMemory: Bool = false, url: URL? = nil) throws {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: StateDocument.self, configurations: configuration)
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
    public func load() throws -> AppState? {
        let documents = try context.fetch(FetchDescriptor<StateDocument>())
        guard documents.count <= 1 else { throw QuestError.invalidState }
        guard let document = documents.first else { return nil }
        return try decode(document.payload)
    }
    public func save(_ state: AppState) throws {
        try validate(state)
        let payload = try JSONEncoder().encode(state)
        let documents = try context.fetch(FetchDescriptor<StateDocument>())
        guard documents.count <= 1 else { throw QuestError.invalidState }
        if let existing = documents.first {
            _ = try decode(existing.payload)
            existing.payload = payload
        } else {
            context.insert(StateDocument(payload: payload))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
    private func decode(_ payload: Data) throws -> AppState {
        do {
            let state = try JSONDecoder().decode(AppState.self, from: payload)
            try validate(state)
            return state
        } catch { throw QuestError.invalidState }
    }
    private func validate(_ state: AppState) throws {
        guard state.version == 1, TimeZone(identifier: state.timeZoneID) != nil else { throw QuestError.invalidState }
        if let preferences = state.preferences {
            guard preferences.nickname.count <= 20,
                  preferences.nickname.rangeOfCharacter(from: .newlines) == nil else { throw QuestError.invalidState }
        }
        let questIDs = Set(state.quests.map(\.id))
        guard questIDs.count == state.quests.count,
              Set(state.completions.map(\.id)).count == state.completions.count else { throw QuestError.invalidState }
        for quest in state.quests {
            let name = quest.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...40).contains(name.count), QuestArtIDs.all.contains(quest.artID),
                  validRewards(quest.rewards), !quest.targetChanges.isEmpty,
                  quest.targetChanges.allSatisfy({ (1...99).contains($0.target) }) else { throw QuestError.invalidState }
        }
        for completion in state.completions {
            guard questIDs.contains(completion.questID), (1...99).contains(completion.target),
                  validRewards(completion.rewards) else { throw QuestError.invalidState }
        }
    }
    private func validRewards(_ rewards: StatPoints) -> Bool {
        Stat.allCases.allSatisfy { (0...2).contains(rewards[$0]) } && rewards.total <= 2
    }
}
