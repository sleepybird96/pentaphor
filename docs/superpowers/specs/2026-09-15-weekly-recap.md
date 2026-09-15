# Weekly recap

User approved Monday 09:00 in the saved record timezone, on cold launch or return from background. Reuse PENTAPHOR's dark ink/paper/teal/gold visual system and existing quest art/radar for a game reward-style weekly result. This is a summary of previously earned growth, never another grant of points.

## Timing and presentation
- Week remains Monday 00:00 to next Monday 00:00. A week's recap becomes available at its end Monday 09:00, after prior-week recording grace. Before that cutoff the latest closed week is one week earlier.
- Automatic checks on loaded home first appearance and each foreground activation. Show only the latest closed week, only with at least one non-void completion, and only when its start is later than the persisted acknowledged-through marker. No backlog queue or empty-week guilt screen.
- Wait for existing editor/settings/archive/onboarding/achievement/dialogs to dismiss. Preserve pending notification routing priority, then recap after the routed editor closes. Do not interrupt editing or claim acknowledgement simply from presentation.
- Acknowledge only from explicit final button, persist atomically, then dismiss. Failed save keeps the recap open with retry/error. Reopening or foregrounding after successful acknowledgement does not replay automatically. History can explicitly replay the latest closed recap. Existing onboarding and launch animation stay intact.

## Attribution
- Weekly completion belongs to its stored weekly period, including Monday-before-09:00 entries explicitly assigned to the prior week.
- Monthly and one-time completions belong to the calendar week of recordedAt. Include archived/deleted quest history and reward snapshots; ignore voided completions. Do not read current quest reward values for earned points.
- Weekly streak bonus belongs to its bonus period. Monthly streak bonus belongs to the calendar week of the target-th non-void completion in that month, sorted by recordedAt then UUID. Thus it appears in the week it was earned, not every week of the month.
- Recap gains = matching completion reward snapshots + attributable perseverance streak bonuses. Before totals = reward snapshots and bonuses attributed to earlier weeks; after = before + gains. Exclude newer-week earnings. Replays recompute from current non-void history, so undo is reflected without re-awarding anything.
- Show total action count, unique quest count, number of weekly goals achieved (snapshot targets), each performed quest's art/name/count and all positive parameter gains. Do not present missed goals as failures.

## UI
`WEEK COMPLETE`, Korean date range, `지난주에 이만큼 쌓았어`. Counts enter first, quest art activity rows follow, then parameter gains and radar animate from before to after with existing vertex pops. Perseverance streak bonus appears separately. Final action `좋아, 다음 한 주로`. Allow scrolling/early final action; no mandatory long wait. Simplified effects and iOS Reduce Motion show settled state; normal animation roughly 2 seconds. No new haptic at recap or points mutation. Accessibility labels expose period/counts/gains and test IDs.

## Interfaces
Core:
- `WeeklyRecapActivity: Identifiable, Equatable, Sendable`: id UUID (questID), name String, artID String, cadence Cadence, count Int; public init.
- `WeeklyRecap: Identifiable, Equatable, Sendable`: computed id Date=period.start; period PeriodWindow; completionCount Int; computed questCount Int; weeklyGoalsAchieved Int; baseGains StatPoints; streakBonus Int; gains StatPoints (includes bonus); before StatPoints; after StatPoints; activities [WeeklyRecapActivity]. Public initializer (period, completionCount, weeklyGoalsAchieved, baseGains, streakBonus, before, activities), derives gains/after.
- `WeeklyRecapBuilder.latestClosedWeek(now: Date, timeZoneID: String) -> PeriodWindow`
- `WeeklyRecapBuilder.build(engine: QuestEngine, period: PeriodWindow) -> WeeklyRecap?`
- `WeeklyRecapBuilder.latest(engine: QuestEngine, now: Date) -> WeeklyRecap?`
- `WeeklyRecapBuilder.pending(engine: QuestEngine, now: Date) -> WeeklyRecap?`
- `AppState.weeklyRecapAcknowledgedThrough: Date? = nil` (legacy Codable compatible).
- `QuestEngine.acknowledgeWeeklyRecap(periodStart: Date, at: Date) throws`: validate closed Monday-start week with nonempty report, advance marker monotonically; never change rewards/records. Invalid requests throw QuestError.invalidState.
App view: `WeeklyRecapView(recap: WeeklyRecap, timeZoneID: String, simplifiedEffects: Bool, onDone: () -> Void)`; parent owns persistence/error presentation, passes closure. Root owns navigation/lifecycle/clock and History integration.

## Verification and delivery
Core dates/09:00/DST/timezone/grace, all cadences/reward snapshots/bonuses/void/archive/delete, latest-only/empty, legacy acknowledgement persistence and no point grant. App coordinator cold/foreground/deferred/routing priority, acknowledge failure and repeat suppression. UI cold recap, background resume, explicit acknowledgement/relaunch/replay and unchanged points. Full default tests and new TestFlight Personal build; preserve bundle app.pentaphor.personal, team NX53XT8XMU, version1 records, internal-only delivery.
