# Goal-aware quest reminders

User approved per-quest multiple weekdays and one time. A weekly target such as 4 completions does not prescribe 4 exact work days: selected reminder days only prompt while the relevant goal remains incomplete.

## Behavior
- Optional reminder in quest create/edit, default off for new and existing quests. Select any nonempty set of weekdays Monday–Sunday plus one hour/minute shared by those days. UI draft changes schedule nothing until the quest save succeeds; cancel preserves prior configuration.
- Weekly: stop remaining reminders in an achieved week and resume in following weeks. Monthly: same weekly reminder schedule, eligibility determined by that month's goal. One-time: stop after completion. Undo restores future eligible reminders. Archive/delete stop all reminders; restore recalculates. Target/name/schedule edits update notifications after save.
- Use the app's saved record time zone for reminder weekdays and clock time. Monday 00:00 begins the new week; the previous-week recording grace through Monday before 09:00 does not shift reminders into the old week. Never create notifications for elapsed times.
- Request system permission only when the user enables reminders or explicitly requests a test. Denial must be visible with a link to iPhone notification settings. Keep saved reminder preferences so allowing notifications later can restore them. No badges or push registration/server.
- Notification title is the quest name. Body states current-week/month remaining count (computed from persisted state) or a gentle one-time reminder. Tap opens that quest's existing editor, after launch data loading; do not mark complete from a notification. Archived/deleted/completed-one-time links fall back to the quest list.
- App in foreground: suppress obsolete/fulfilled reminder notifications and present eligible ones. First launch introduction and progress remain unchanged.
- Settings shows permission status, scheduling errors and a real 5-second test notification button when allowed. Test notifications do not mutate records or points.

## Local scheduling contract and limits
Use iOS UserNotifications and one-shot requests so achieving a goal cancels only that period, while later periods remain scheduled. Generate up to 42 calendar days ahead, retain at most the earliest 60 quest notification requests globally (stable sorting by timestamp then quest id). The test notification is separate and at most one request. Refill on launch/foreground and every successfully persisted state change. No reliance on an OS background wake or a server. Long absence from the app can exhaust the reserved notifications; state this plainly in settings. Do not claim indefinite scheduling.

Use deterministic request IDs with a `pentaphor.quest.` prefix, quest ID and fire instant. Reconciliation only touches app-owned reminder IDs; serial/coalescing updates must converge on the latest persisted state even when a previous add is in flight. Scheduling failure is visible and retryable, never reported as scheduled. Permission denial clears pending owned reminders. Keep credentials, signing, bundle ID, existing version-1 records and other notifications intact.

DST: calendar wall-clock matching using `.nextTime` and first repeated time; ensure at most one reminder per selected calendar day. Future-week/month content is calculated for that future period, not carried over from this week's progress.

## Interfaces
Core `QuestReminder`: Codable, Equatable, Sendable, fields `weekdays: [Int]` (Calendar 1=Sunday..7=Saturday), `hour: Int`, `minute: Int`, public initializer, `isValid` property. Validation requires distinct nonempty weekdays in 1...7 and valid clock components. `Quest.reminder: QuestReminder? = nil` decodes missing old data; invalid decoded values are rejected at repository validation. `QuestEngine.updateReminder(id: UUID, reminder: QuestReminder?) throws` updates only the reminder; editor wraps create/update and updateReminder in one store transaction.

Core `PlannedQuestReminder`: Equatable, Sendable, Identifiable, `id: String`, `questID: UUID`, `fireDate: Date`, `title: String`, `body: String`.
Core `QuestReminderPlanner.plan(engine: QuestEngine, now: Date, horizonDays: Int = 42, limit: Int = 60) -> [PlannedQuestReminder]`.

App `@MainActor @Observable QuestReminderService`: `authorization: ReminderAuthorization` (`unknown`, `notDetermined`, `denied`, `allowed`), `errorMessage: String?`, `scheduledCount: Int`, `requestPermission() async`, `synchronize(state: AppState) async`, `sendTest() async`. State synchronization rechecks system authorization. `@Environment(QuestReminderService.self)` for create/edit and settings; parent owns one instance for the app lifetime. An injectable notification-center boundary isolates platform effects in native tests.

## Acceptance
Core tests: old JSON, invalid inputs/decoded state, off, weekday/time/time-zone/DST dates, weekly rollover and grace, monthly/one-time goals, undo/archive/delete/restore, target edits, bounded stable sorting and no past alerts.
Native service tests: allowed/denied permissions, cancel fulfilled/current vs retain future periods, edit replacement, failure reporting and retry, overlapping reconciliations converge, notification route parsing, test request isolation.
UI: choose weekdays/time, cancel vs save/relaunch persistence, permission response/status, real scheduled test notification without awarding points. Run full existing tests plus new suites, archive/upload using default API workflow, verify Personal READY.

## Settings master toggle — 2026-09-15 refinement
The user requested a visible toggle like the other settings instead of the permission text button. The settings section now leads with a quest-reminder toggle. It persists a global reminder preference while preserving every per-quest day/time. Existing data with no new field defaults to enabled, preserving build 5 behavior. An effective ON display requires both the app preference and allowed system authorization.

Turning OFF cancels owned quest and test requests, suppresses their foreground presentation and blocks new test requests; future launch/state changes keep the preference. Turning ON restores eligible quest requests. The first ON action requests system authorization; an existing denial leads to native notification settings, while declining a new permission prompt stays in-app with explanatory settings access. Permissions remain owned by iOS. A failed preference save must not change scheduling or trigger permission work. Quest editors explain global OFF and preserve drafts/settings without silently re-enabling the global preference.

Acceptance: legacy decode remains enabled; OFF persists across JSON/relaunch, cancels pending requests without touching unrelated IDs, preserves quest settings/points and re-enabling restores eligible requests. UI toggle appears alongside existing-style settings and persists across relaunch. Real OS test notification remains available when enabled. Full default internal delivery applies.
