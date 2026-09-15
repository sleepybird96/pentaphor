# One-time Quests Implementation Plan

> **For agentic workers:** Use inline execution in this already active feature checkout, following test-driven-development and verification-before-completion. Steps use checkbox syntax for tracking.

**Goal:** Add one-time quests and present all active quests in one list.
**Architecture:** Extend Cadence with a canonical lifetime window, derive completion state from nonvoided records, keep the existing version-1 payload. Adapt the editor and list while leaving recurring calculations unchanged.
**Tech Stack:** Swift 6, Swift Testing, SwiftData, SwiftUI, XCTest; iOS 17+.
**Spec:** `docs/superpowers/specs/2026-09-15-one-time-quests.md`

## Global Constraints

- Preserve Monday 00:00 rollover / previous-week entry before Monday 09:00.
- No migration, signing changes, external distribution, or user-data reset.
- Existing quest creation order, default 매주 / 3회, and max 2 allocated points stay unchanged.

### Task 1: Domain and persistence

Files: `PeriodCalculator.swift`, `Domain.swift`, `QuestEngine.swift`, `StateRepository.swift` under `Packages/PentaphorCore/Sources/PentaphorCore/`; new `Tests/PentaphorCoreTests/OneTimeQuestTests.swift`.
Interface: `Cadence.once`, `QuestError.alreadyCompleted`; existing engine create/update/complete/undo/progress APIs stay unchanged.

- [x] Add failing behavioral tests: late completion still has count 1, hidden active quest, second completion rejected without changes, undo/recomplete restores 2 points with zero streak, archive/delete never revived by undo, target != 1 rejected, cadence locked after void, disk reopen and malformed payload rejection.
- [x] Run `swift test --package-path Packages/PentaphorCore --filter OneTimeQuestTests`; confirm absent behavior fails.
- [x] Implement `.once` period as `PeriodWindow(start: .distantPast, end: .distantFuture, cadence: .once)`, filter finished one-time IDs from activeQuests, reject a second nonvoided record, return no streak/bonus, require target 1, validate persisted invariants.
- [x] Run full `swift test --package-path Packages/PentaphorCore`; keep the existing legacy JSON compatibility test green.

### Task 2: Native UI

Files: `Pentaphor/Views/{QuestHome,QuestEditor,DesignSystem,AchievementView,JournalViews,IntroductionView,SettingsView}.swift`, `PentaphorUITests/PentaphorUITests.swift`.
Consumes existing `activeQuests`, `progress`, `complete`, `undo` plus `Cadence.once`.

- [x] Write acceptance test creating monthly then weekly then one-time quests. Assert no section headers and creation order; select 한 번, assert stepper absent; complete, relaunch, assert absent and 2 points; undo via history, assert active and 0 points; complete and undo from achievement.
- [x] Run focused native test before UI implementation and confirm missing one-time choice/header behavior causes failure.
- [x] Use one `ForEach(store.engine.activeQuests)`, exhaustive cadence Korean labels, hide stepper and save target 1 for once. Keep selected recurring count when toggling options. History labels once “한 번 · 완료”; achievement says stored in history. Update introductory/rules copy.
- [x] Run all UI tests on simulator B3147374-5BC7-48E0-952D-C3E55BE423C3 using `/tmp/pentaphor-memo-touch`; inspect screenshots from the new test.

### Task 3: Verify and document

- [x] Run a signed generic iOS build, review diff for accidental changes and one-time lifecycle edge cases.
- [x] Update README/development log with actual RED/GREEN results, inspect screenshots, commit only explicit changed files.
