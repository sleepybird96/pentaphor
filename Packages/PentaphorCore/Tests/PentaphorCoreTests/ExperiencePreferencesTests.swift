import Foundation
import Testing
@testable import PentaphorCore

@MainActor struct ExperiencePreferencesTests {
    @Test func freshStorePersistsUnfinishedIntroduction() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        _ = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let saved = try #require(try repository.load())
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        let preferences = try #require(json["preferences"] as? [String: Any])
        #expect(preferences["hasCompletedOnboarding"] as? Bool == false)
        #expect(preferences["hasCreatedFirstQuest"] as? Bool == false)
    }

    @Test func savedPreferencesSurviveRoundTripAlongsideLegacyRecords() throws {
        var engine = emptyEngine()
        let quest = try engine.create(name: "수영", artID: "swimming", cadence: .week, target: 3, rewards: StatPoints(stamina: 2), at: created)
        _ = try engine.complete(questID: quest.id, at: created)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(engine.state)) as? [String: Any])
        json["preferences"] = ["nickname": "지상", "hasCompletedOnboarding": true, "hasCreatedFirstQuest": true, "hapticsEnabled": false, "simplifiedEffects": true]
        let state = try JSONDecoder().decode(AppState.self, from: JSONSerialization.data(withJSONObject: json))
        let repository = try SwiftDataStateRepository(inMemory: true)
        try repository.save(state)
        let reopened = try QuestStore(repository: repository, timeZoneID: "America/New_York")
        let result = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(reopened.engine.state)) as? [String: Any])
        let preferences = try #require(result["preferences"] as? [String: Any])
        #expect(preferences["nickname"] as? String == "지상")
        #expect(preferences["hapticsEnabled"] as? Bool == false)
        #expect(preferences["simplifiedEffects"] as? Bool == true)
        #expect(reopened.engine.state.quests == engine.state.quests)
        #expect(reopened.engine.state.completions == engine.state.completions)
        #expect(reopened.engine.state.timeZoneID == "Asia/Seoul")
        #expect(reopened.engine.totals.stamina == 2)
    }
}

@MainActor private final class PreferencesFailingRepository: StateRepository {
    var saved: AppState?
    var fails = false
    func load() throws -> AppState? { saved }
    func save(_ state: AppState) throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        saved = state
    }
}

extension ExperiencePreferencesTests {
    @Test func firstQuestHelpEndsOnlyAfterSuccessfulCreation() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let store = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        #expect(!store.engine.preferences.hasCreatedFirstQuest)
        #expect(throws: QuestError.invalidName) {
            try store.transact { try $0.create(name: "", artID: "reading", cadence: .week, target: 1, rewards: .zero, at: created) }
        }
        #expect(!store.engine.preferences.hasCreatedFirstQuest)
        _ = try store.transact { try $0.create(name: "독서", artID: "reading", cadence: .week, target: 1, rewards: StatPoints(knowledge: 2), at: created) }
        #expect(store.engine.preferences.hasCreatedFirstQuest)
        #expect(store.engine.totals == .zero)
        #expect(try QuestStore(repository: repository).engine.preferences.hasCreatedFirstQuest)
    }

    @Test func legacyPayloadBypassesIntroductionEvenWithoutQuests() throws {
        let payload = Data(#"{"version":1,"timeZoneID":"Asia/Seoul","quests":[],"completions":[]}"#.utf8)
        let state = try JSONDecoder().decode(AppState.self, from: payload)
        let engine = QuestEngine(state: state)
        #expect(engine.preferences.hasCompletedOnboarding)
        #expect(engine.preferences.hasCreatedFirstQuest)
        #expect(engine.preferences.nickname.isEmpty)
        #expect(engine.state == state)
    }

    @Test func nicknameIsNormalizedAndPreferencesSurviveDiskReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("experience.store")
        do {
            let store = try QuestStore(repository: SwiftDataStateRepository(url: url), timeZoneID: "Asia/Seoul")
            var value = store.engine.preferences
            value.nickname = "  지상  "
            value.hasCompletedOnboarding = true
            value.hapticsEnabled = false
            value.simplifiedEffects = true
            try store.transact { try $0.updatePreferences(value) }
        }
        let reopened = try QuestStore(repository: SwiftDataStateRepository(url: url), timeZoneID: "America/New_York")
        #expect(reopened.engine.preferences.nickname == "지상")
        #expect(reopened.engine.preferences.hasCompletedOnboarding)
        #expect(!reopened.engine.preferences.hapticsEnabled)
        #expect(reopened.engine.preferences.simplifiedEffects)
        #expect(reopened.engine.state.timeZoneID == "Asia/Seoul")
        #expect(reopened.engine.totals == .zero)
        var cleared = reopened.engine.preferences
        cleared.nickname = "   "
        try reopened.transact { try $0.updatePreferences(cleared) }
        #expect(reopened.engine.preferences.nickname == "")
        #expect(reopened.engine.preferences.hasCompletedOnboarding)
    }

    @Test(arguments: [String(repeating: "가", count: 21), "한\n줄", "한\r줄"])
    func invalidNicknameDoesNotChangeState(_ nickname: String) throws {
        var engine = emptyEngine()
        let original = engine.state
        var candidate = engine.preferences
        candidate.nickname = nickname
        #expect(throws: PreferencesError.invalidNickname) { try engine.updatePreferences(candidate) }
        #expect(engine.state == original)
    }

    @Test func failedPreferenceSaveDoesNotDismissIntroductionOrChangeStoredData() throws {
        let repository = PreferencesFailingRepository()
        let store = try QuestStore(repository: repository, timeZoneID: "Asia/Seoul")
        let original = store.engine.state
        var candidate = store.engine.preferences
        candidate.nickname = "지상"
        candidate.hasCompletedOnboarding = true
        repository.fails = true
        #expect(throws: CocoaError.self) { try store.transact { try $0.updatePreferences(candidate) } }
        #expect(store.engine.state == original)
        #expect(repository.saved == original)
        #expect(!store.engine.preferences.hasCompletedOnboarding)
    }

    @Test func systemReducedMotionAlwaysOverridesFullEffectsPreference() {
        var preferences = ExperiencePreferences()
        #expect(!preferences.usesSimplifiedEffects(systemReduceMotion: false))
        #expect(preferences.usesSimplifiedEffects(systemReduceMotion: true))
        preferences.simplifiedEffects = true
        #expect(preferences.usesSimplifiedEffects(systemReduceMotion: false))
        #expect(preferences.usesSimplifiedEffects(systemReduceMotion: true))
    }

    @Test func repositoryRejectsInvalidNicknameWithoutReplacingSavedState() throws {
        let repository = try SwiftDataStateRepository(inMemory: true)
        let original = AppState(timeZoneID: "Asia/Seoul")
        try repository.save(original)
        var invalid = original
        var preferences = ExperiencePreferences()
        preferences.nickname = String(repeating: "가", count: 21)
        invalid.preferences = preferences
        #expect(throws: QuestError.invalidState) { try repository.save(invalid) }
        #expect(try repository.load() == original)
    }
}
