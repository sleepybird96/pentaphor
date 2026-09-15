import Foundation

public struct QuestEngine: Sendable {
    public private(set) var state: AppState
    public init(state: AppState) { self.state = state }
    public var preferences: ExperiencePreferences { state.preferences ?? .establishedUser }
    public mutating func updatePreferences(_ preferences: ExperiencePreferences) throws {
        var candidate = preferences
        candidate.nickname = candidate.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.nickname.count <= 20,
              candidate.nickname.rangeOfCharacter(from: .newlines) == nil else { throw PreferencesError.invalidNickname }
        state.preferences = candidate
    }
    public mutating func acknowledgeWeeklyRecap(periodStart: Date, at date: Date) throws {
        guard periodStart.timeIntervalSinceReferenceDate.isFinite,
              date.timeIntervalSinceReferenceDate.isFinite else { throw QuestError.invalidState }
        let period = calculator.period(containing: periodStart, cadence: .week)
        let latest = WeeklyRecapBuilder.latestClosedWeek(now: date, timeZoneID: state.timeZoneID)
        guard period.start == periodStart, period.start <= latest.start,
              WeeklyRecapBuilder.build(engine: self, period: period) != nil else { throw QuestError.invalidState }
        if state.weeklyRecapAcknowledgedThrough.map({ periodStart > $0 }) ?? true {
            state.weeklyRecapAcknowledgedThrough = periodStart
        }
    }
    public var calculator: PeriodCalculator { PeriodCalculator(timeZoneID: state.timeZoneID) }
    public var activeQuests: [Quest] {
        let completedIDs = Set(state.completions.filter { !$0.isVoided }.map(\.questID))
        return state.quests.filter { !$0.isArchived && $0.deletedAt == nil && ($0.cadence != .once || !completedIDs.contains($0.id)) }
    }
    public var archivedQuests: [Quest] { state.quests.filter { $0.isArchived && $0.deletedAt == nil } }
    public mutating func delete(id: UUID, at date: Date) throws {
        guard let index = state.quests.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { throw QuestError.notFound }
        // Keep the definition for historical labels and earned streak bonuses.
        state.quests[index].deletedAt = date
    }
    public func canRecordPreviousWeek(for quest: Quest, at date: Date) -> Bool {
        quest.cadence == .week && calculator.canRecordPreviousWeek(at: date)
            && quest.createdAt < calculator.period(containing: date, cadence: .week).start
    }
    public var totals: StatPoints {
        var total = state.completions.filter { !$0.isVoided }.reduce(StatPoints.zero) { $0 + $1.rewards }
        total.perseverance += bonuses.count
        return total
    }
    public var bonuses: [StreakBonus] {
        state.quests.flatMap { quest -> [StreakBonus] in
            guard quest.cadence != .once else { return [] }
            let groups = Dictionary(grouping: state.completions.filter { $0.questID == quest.id && !$0.isVoided }, by: \.period)
            let qualified = groups.filter { $0.value.count >= ($0.value.first?.target ?? Int.max) }.map(\.key).sorted { $0.start < $1.start }
            var last: PeriodWindow?
            var streak = 0
            return qualified.compactMap { period in
                streak = last?.end == period.start && last?.cadence == period.cadence ? streak + 1 : 1
                last = period
                return streak >= 2 ? StreakBonus(questID: quest.id, period: period, streak: streak) : nil
            }
        }.sorted { $0.period.start < $1.period.start }
    }
    public func target(for quest: Quest, period: PeriodWindow) -> Int {
        if let snapshot = state.completions.first(where: { $0.questID == quest.id && $0.period == period }) { return snapshot.target }
        return quest.targetChanges.filter { $0.effectiveFrom <= period.start }.max { $0.effectiveFrom < $1.effectiveFrom }?.target ?? quest.targetChanges.first?.target ?? 1
    }
    public func progress(for quest: Quest, at date: Date) -> QuestProgress {
        let period = calculator.period(containing: date, cadence: quest.cadence)
        let count = state.completions.filter { $0.questID == quest.id && $0.period == period && !$0.isVoided }.count
        return QuestProgress(period: period, count: count, target: target(for: quest, period: period))
    }
    @discardableResult
    public mutating func complete(questID: UUID, at date: Date, previousWeek: Bool = false, requestID: UUID = UUID()) throws -> CompletionResult {
        if let existing = state.completions.first(where: { $0.id == requestID }) {
            guard existing.questID == questID, !existing.isVoided else { throw QuestError.duplicateRequest }
            return CompletionResult(completion: existing, before: totals, after: totals, bonus: 0, streak: 0)
        }
        guard let quest = state.quests.first(where: { $0.id == questID && $0.deletedAt == nil }) else { throw QuestError.notFound }
        guard !quest.isArchived else { throw QuestError.archived }
        if quest.cadence == .once, state.completions.contains(where: { $0.questID == questID && !$0.isVoided }) {
            throw QuestError.alreadyCompleted
        }
        var period = calculator.period(containing: date, cadence: quest.cadence)
        if previousWeek {
            guard quest.cadence == .week, calculator.canRecordPreviousWeek(at: date) else { throw QuestError.graceExpired }
            period = calculator.previous(to: period)
        }
        guard date >= quest.createdAt, period.end > quest.createdAt else { throw QuestError.predatesQuest }
        let before = totals
        let oldBonuses = Set(bonuses.map(\.id))
        let completion = Completion(id: requestID, questID: questID, recordedAt: date, period: period, target: target(for: quest, period: period), rewards: quest.rewards, isVoided: false)
        state.completions.append(completion)
        let added = bonuses.filter { !oldBonuses.contains($0.id) }
        let streak = quest.cadence == .once ? 0 : bonuses.first { $0.questID == questID && $0.period == period }?.streak ?? added.map(\.streak).max() ?? (progress(for: quest, at: period.start).achieved ? 1 : 0)
        return CompletionResult(completion: completion, before: before, after: totals, bonus: added.count, streak: streak)
    }
    public mutating func undo(completionID: UUID) throws {
        guard let index = state.completions.firstIndex(where: { $0.id == completionID }) else { throw QuestError.notFound }
        state.completions[index].isVoided = true
    }
    public mutating func update(id: UUID, name: String, artID: String, cadence: Cadence, target: Int, rewards: StatPoints, at date: Date, notes: String? = nil) throws {
        guard let index = state.quests.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { throw QuestError.notFound }
        guard cadence != .once || target == 1 else { throw QuestError.invalidTarget }
        let name = try validatedName(name, artID: artID, target: target, rewards: rewards)
        var quest = state.quests[index]
        let records = state.completions.filter { $0.questID == id }
        guard cadence == quest.cadence || records.isEmpty else { throw QuestError.cadenceLocked }
        let current = calculator.period(containing: date, cadence: cadence)
        if cadence != quest.cadence || cadence == .once {
            quest.targetChanges = [TargetChange(effectiveFrom: current.start, target: target)]
        } else {
            quest.targetChanges.removeAll { $0.effectiveFrom >= current.start }
            quest.targetChanges.append(TargetChange(effectiveFrom: current.start, target: target))
        }
        // Current-period goal edits also govern qualification and reminders that read snapshots.
        // Include voided records so they cannot retain a stale target when activity resumes.
        for completionIndex in state.completions.indices {
            let completion = state.completions[completionIndex]
            guard completion.questID == id, completion.period == current else { continue }
            state.completions[completionIndex] = Completion(
                id: completion.id, questID: completion.questID, recordedAt: completion.recordedAt,
                period: completion.period, target: target, rewards: completion.rewards,
                isVoided: completion.isVoided)
        }
        quest.name = name; quest.artID = artID; quest.cadence = cadence; quest.rewards = rewards
        if let notes { quest.notes = notes.isEmpty ? nil : notes }
        state.quests[index] = quest
    }
    public mutating func updateReminder(id: UUID, reminder: QuestReminder?) throws {
        guard let index = state.quests.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { throw QuestError.notFound }
        guard reminder?.isValid != false else { throw QuestError.invalidReminder }
        state.quests[index].reminder = reminder
    }
    public mutating func setArchived(id: UUID, archived: Bool) throws {
        guard let index = state.quests.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { throw QuestError.notFound }
        state.quests[index].isArchived = archived
    }
    @discardableResult
    public mutating func create(name: String, artID: String, cadence: Cadence, target: Int, rewards: StatPoints, at date: Date, notes: String = "", id: UUID = UUID()) throws -> Quest {
        guard !state.quests.contains(where: { $0.id == id }) else { throw QuestError.duplicateRequest }
        guard cadence != .once || target == 1 else { throw QuestError.invalidTarget }
        let name = try validatedName(name, artID: artID, target: target, rewards: rewards)
        let quest = Quest(id: id, name: name, artID: artID, cadence: cadence, createdAt: date, isArchived: false, rewards: rewards, targetChanges: [TargetChange(effectiveFrom: calculator.period(containing: date, cadence: cadence).start, target: target)], notes: notes.isEmpty ? nil : notes)
        state.quests.append(quest)
        if state.preferences != nil { state.preferences?.hasCreatedFirstQuest = true }
        return quest
    }
    private func validatedName(_ name: String, artID: String, target: Int, rewards: StatPoints) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmed.count) else { throw QuestError.invalidName }
        guard QuestArtIDs.all.contains(artID) else { throw QuestError.invalidArt }
        guard (1...99).contains(target) else { throw QuestError.invalidTarget }
        guard Stat.allCases.allSatisfy({ (0...2).contains(rewards[$0]) }), rewards.total <= 2 else { throw QuestError.invalidRewards }
        return trimmed
    }
}
