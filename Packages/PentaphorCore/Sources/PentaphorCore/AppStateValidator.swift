import Foundation

/// Shared persistence and import validation. Historical reward/target snapshots remain authoritative.
public enum AppStateValidator {
    public static func validate(_ state: AppState) throws {
        guard state.version == 1, TimeZone(identifier: state.timeZoneID) != nil else { throw QuestError.invalidState }
        if let marker = state.weeklyRecapAcknowledgedThrough {
            guard isSupportedDate(marker),
                  PeriodCalculator(timeZoneID: state.timeZoneID).period(containing: marker, cadence: .week).start == marker
            else { throw QuestError.invalidState }
        }
        if let preferences = state.preferences {
            guard preferences.nickname.count <= 20,
                  preferences.nickname.rangeOfCharacter(from: .newlines) == nil else { throw QuestError.invalidState }
        }
        let questIDs = Set(state.quests.map(\.id))
        guard questIDs.count == state.quests.count,
              Set(state.completions.map(\.id)).count == state.completions.count else { throw QuestError.invalidState }
        let recordsByQuest = Dictionary(grouping: state.completions, by: \.questID)
        for quest in state.quests {
            let name = quest.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...40).contains(name.count), QuestArtIDs.all.contains(quest.artID),
                  isSupportedDate(quest.createdAt),
                  quest.deletedAt.map(isSupportedDate) != false,
                  validRewards(quest.rewards), quest.reminder?.isValid != false, !quest.targetChanges.isEmpty,
                  quest.targetChanges.allSatisfy({ (1...99).contains($0.target) && isSupportedDate($0.effectiveFrom) }) else { throw QuestError.invalidState }
            if quest.cadence == .once {
                let records = recordsByQuest[quest.id] ?? []
                let lifetime = PeriodCalculator(timeZoneID: state.timeZoneID).period(containing: quest.createdAt, cadence: .once)
                guard quest.targetChanges.allSatisfy({ $0.target == 1 }),
                      records.filter({ !$0.isVoided }).count <= 1,
                      records.allSatisfy({ $0.target == 1 && $0.period == lifetime }) else { throw QuestError.invalidState }
            }
        }
        let questsByID = Dictionary(uniqueKeysWithValues: state.quests.map { ($0.id, $0) })
        let calculator = PeriodCalculator(timeZoneID: state.timeZoneID)
        var targetsByQuestAndPeriod: [UUID: [PeriodWindow: Int]] = [:]
        for completion in state.completions {
            guard let quest = questsByID[completion.questID], (1...99).contains(completion.target),
                  validRewards(completion.rewards), isSupportedDate(completion.recordedAt),
                  isSupportedDate(completion.period.start), isSupportedDate(completion.period.end),
                  completion.period.start < completion.period.end,
                  completion.period.cadence == quest.cadence,
                  calculator.period(containing: completion.period.start, cadence: completion.period.cadence) == completion.period
            else { throw QuestError.invalidState }
            // Voided records participate in target lookup too. Every snapshot for
            // this quest and period must agree; rewards may differ after edits.
            if let target = targetsByQuestAndPeriod[completion.questID]?[completion.period], target != completion.target {
                throw QuestError.invalidState
            }
            targetsByQuestAndPeriod[completion.questID, default: [:]][completion.period] = completion.target
        }
    }
    // Calendar calculations must never receive arbitrary finite-but-unrepresentable
    // JSON dates. These bounds also retain the existing one-time period sentinels.
    static func isSupportedDate(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite && date >= .distantPast && date <= .distantFuture
    }
    private static func validRewards(_ rewards: StatPoints) -> Bool {
        Stat.allCases.allSatisfy { (0...2).contains(rewards[$0]) } && rewards.total <= 2
    }
}
