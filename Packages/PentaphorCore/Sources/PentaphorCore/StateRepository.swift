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
        try AppStateValidator.validate(state)
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
            try AppStateValidator.validate(state)
            return state
        } catch { throw QuestError.invalidState }
    }
}
