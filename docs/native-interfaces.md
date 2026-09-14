# Native UI / core boundary

All types are public in local package `PentaphorCore`. Use `import PentaphorCore`.

```swift
enum Cadence: String, Codable, CaseIterable, Sendable { case week, month }
enum Stat: String, Codable, CaseIterable, Identifiable, Sendable {
    case stamina, knowledge, perseverance, charm, courage
    var id: String { rawValue }
    var title: String // 체력 지식 끈기 매력 용기
}
struct StatPoints: Codable, Equatable, Sendable {
    init(stamina: Int = 0, knowledge: Int = 0, perseverance: Int = 0, charm: Int = 0, courage: Int = 0)
    subscript(_ stat: Stat) -> Int { get set }
    var total: Int
    static var zero: StatPoints
}
struct PeriodWindow: Codable, Equatable, Hashable, Sendable {
    let start: Date; let end: Date; let cadence: Cadence
}
struct TargetChange: Codable, Equatable, Sendable {
    let effectiveFrom: Date; let target: Int
}
struct Quest: Identifiable, Codable, Equatable, Sendable {
    let id: UUID; var name: String; var artID: String; var cadence: Cadence
    let createdAt: Date; var isArchived: Bool; var rewards: StatPoints
    var targetChanges: [TargetChange]
    var notes: String? // Missing in legacy v1 records; nil means no memo.
    var deletedAt: Date? // Missing in legacy v1 records; nil means not deleted.
}
struct Completion: Identifiable, Codable, Equatable, Sendable {
    let id: UUID; let questID: UUID; let recordedAt: Date; let period: PeriodWindow
    let target: Int; let rewards: StatPoints; var isVoided: Bool
}
struct AppState: Codable, Equatable, Sendable {
    init(timeZoneID: String)
    var version: Int; var timeZoneID: String; var quests: [Quest]; var completions: [Completion]
}
struct QuestProgress { let period: PeriodWindow; let count: Int; let target: Int; var achieved: Bool }
struct StreakBonus: Identifiable { var id: String; let questID: UUID; let period: PeriodWindow; let streak: Int }
struct CompletionResult {
    let completion: Completion; let before: StatPoints; let after: StatPoints
    let bonus: Int; let streak: Int
}
struct PeriodCalculator {
    init(timeZoneID: String)
    func period(containing date: Date, cadence: Cadence) -> PeriodWindow
    func previous(to period: PeriodWindow) -> PeriodWindow
    func canRecordPreviousWeek(at date: Date) -> Bool
}
struct QuestEngine {
    init(state: AppState)
    private(set) var state: AppState
    var totals: StatPoints; var bonuses: [StreakBonus]
    var calculator: PeriodCalculator
    var activeQuests: [Quest]; var archivedQuests: [Quest]
    func progress(for quest: Quest, at date: Date) -> QuestProgress
    func target(for quest: Quest, period: PeriodWindow) -> Int
    mutating func create(name: String, artID: String, cadence: Cadence, target: Int, rewards: StatPoints, at: Date, notes: String = "", id: UUID = UUID()) throws -> Quest
    mutating func update(id: UUID, name: String, artID: String, cadence: Cadence, target: Int, rewards: StatPoints, at: Date, notes: String? = nil) throws
    mutating func setArchived(id: UUID, archived: Bool) throws
    mutating func delete(id: UUID, at: Date) throws
    mutating func complete(questID: UUID, at: Date, previousWeek: Bool = false, requestID: UUID = UUID()) throws -> CompletionResult
    mutating func undo(completionID: UUID) throws
}
@MainActor protocol StateRepository {
    func load() throws -> AppState?
    func save(_ state: AppState) throws
}
@MainActor final class SwiftDataStateRepository: StateRepository {
    init(inMemory: Bool = false, url: URL? = nil) throws
}
@MainActor @Observable final class QuestStore {
    private(set) var engine: QuestEngine
    init(repository: any StateRepository, timeZoneID: String = TimeZone.current.identifier) throws
    @discardableResult func transact<T>(_ mutation: (inout QuestEngine) throws -> T) throws -> T
}
```

Names in errors use `LocalizedError.errorDescription` Korean copy. Art IDs are validated against the approved 60 IDs by core; UI supplies entries from the same catalog. Screens use current `Date()` for actions and `TimelineView(.periodic(from: .now, by: 30))` or foreground refresh to update displayed period/grace state.

Activity list gets labels/art from quest definition; stored rewards/periods remain authoritative. State is initially empty. Capture before/after result only after a successful transaction, then present achievement; on error, show an alert and keep current screen/state.

Notes are optional quest metadata, not completion snapshots. Preserve multiline text exactly. `update(notes: nil)` preserves the previous memo; `update(notes: "")` clears it. Legacy records missing `notes` decode as nil. Editor drafts are local until Save commits through QuestStore.

Deletion marks the quest with `deletedAt` and retains its definition for history labels and streak calculations. List screens use `activeQuests` / `archivedQuests`, both excluding deleted quests. History and totals continue to use all definitions and completion snapshots. Deleted quests reject new completions, updates and archive/restore operations; an already recorded completion request remains idempotent. Save failure never publishes the deletion. `quest.delete` opens a confirmation alert before committing.

UI acceptance selectors: `quest.create`, `quest.name`, `quest.target`, `quest.save`, `quest.complete.<name>`, `achievement.title`, `achievement.undo`, `achievement.done`, `tab.history`, `tab.stats`.

`RadarGrowth` is presentation-only geometry: `fraction(points:)` maps nonnegative points with `x / (x + 50)`. `radii(from:to:progress:emphasizeGrowth:)` returns radii in `Stat.allCases` order, with the existing 0.15 center footprint and 0.78 usable span. Increased axes add two decaying outward pulses over normalized progress 0...1, bounded to 0.99; unchanged axes never move. Polygons and vertex markers are animatable Shapes using this same function. Achievement uses a 0.95s linear animation timeline; Reduce Motion skips it. Numeric labels and stored points remain exact and uncapped by the chart.

Previous-week UI eligibility: `engine.canRecordPreviousWeek(for: quest, at: tapDate)` uses one fresh interaction timestamp; never pass a period cached by the screen. Completion validates the actual commit timestamp again.
