# PENTAPHOR iOS Foundation Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for independently delegated tasks and test-driven-development for every behavior. Keep core domain and transaction work in one local implementation sequence.

**Goal:** Installable native iPhone first-use app with reliable local quest records and stat growth.

**Architecture:** Codable domain state and pure calendar/ledger calculations live in PentaphorCore. A transactional SwiftData repository persists one versioned state document. SwiftUI renders core projections and commits through the store.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XCTest UI tests, XcodeGen, iOS 17.0 / macOS 14.0.

**Spec:** `docs/superpowers/specs/2026-09-11-ios-foundation-design.md`

## Global Constraints

- Minimum iOS 17.0. No external runtime packages or network requests.
- Week starts Monday 00:00; previous-week recording is explicitly selected and only available Monday before 09:00.
- Store the initial time zone; preserve historical reward/target snapshots.
- Maximum 2 assigned stat points per completion; consecutive-period perseverance bonus is separate.
- Show categories and pictures, not art titles; preserve custom quest names.
- Real user starts empty. Do not change signing accounts or publish builds.

## Task 1: Period and quest contracts

Files: `Packages/PentaphorCore/Package.swift`, `Sources/PentaphorCore/Domain.swift`, `PeriodCalculator.swift`; `Tests/PentaphorCoreTests/PeriodCalculatorTests.swift`, `QuestEngineTests.swift`.

Public interface: `Cadence.week/month`, `Stat.stamina/knowledge/perseverance/charm/courage`; `StatPoints` named integer fields and stat subscript. `PeriodWindow(start:end:cadence:)`. `PeriodCalculator(timeZoneID:)` with `period(containing:cadence:)`, `previous(to:)`, `canRecordPreviousWeek(at:)`.

- [ ] Write failing table tests: Seoul Monday 2026-09-14 00:00 starts current week; 08:59:59 permits previous, 09:00 denies; leap-February and New York DST boundaries match hand-derived dates.
- [ ] Run `swift test --package-path Packages/PentaphorCore`, capture RED evidence in `docs/development-log.md`.
- [ ] Implement calendar math using Calendar date intervals with Gregorian calendar and Monday first weekday.
- [ ] Add domain validation tests for blank name, target 0/100, negative rewards and sum 3; preserve valid zero allocation.
- [ ] Implement validation and run GREEN.

## Task 2: Completion ledger and reversible growth

Files: `Sources/PentaphorCore/QuestEngine.swift`, `Tests/PentaphorCoreTests/CompletionTests.swift`.

Interfaces: value type `QuestEngine(state: AppState)` with public read-only `state`, `totals`, `bonuses`; mutations `create`, `update`, `setArchived`, `complete`, `undo`. All mutations validate before changing state. `CompletionResult` exposes completion, before, after, bonus. UI reads quest progress through engine, never by counting raw rows itself.

- [ ] RED: one completion adds assigned rewards; repeated request UUID adds once; second consecutive week/month adds exactly one perseverance; excess completions add no duplicate bonus.
- [ ] Implement snapshot activity ledger and bonus projection. Re-run to GREEN.
- [ ] RED: previous-week record denied outside grace; new current-week quest cannot receive prior-week record; undo last and earlier qualifying completions recomputes dependent bonus.
- [ ] Implement validated grace path and voided records. Re-run to GREEN.
- [ ] RED: edited rewards do not change history; target edits after activity take effect next period; archive retains stats and rejects completion; restore permits recording.
- [ ] Implement effective target changes and archive state. Re-run to GREEN.

## Task 3: Durable transactions

Files: `StateRepository.swift`, `QuestStore.swift`; `RepositoryTests.swift`, `StoreTests.swift`.

Interfaces: `@MainActor StateRepository` protocol `load() throws -> AppState?`, `save(_:) throws`; `SwiftDataStateRepository` supports supplied ModelConfiguration for memory/disk. `@MainActor @Observable QuestStore` exposes engine and wraps mutations in copy→save→publish.

- [ ] RED: write actual disk store, destroy container, reopen and verify records/voids/timezone. Corrupt/unknown payload is rejected without overwriting.
- [ ] Implement SwiftData envelope and version validation. Re-run GREEN.
- [ ] RED: injected failing storage leaves published quest state unchanged; successful save survives reload.
- [ ] Implement transactional store, then GREEN across core suite.

## Task 4: Native presentation and app packaging

Files: `Pentaphor/App`, `Pentaphor/Views`, `Pentaphor/Resources`, `project.yml`, `Pentaphor.xcodeproj`, `PentaphorUITests`.

- [ ] Write UI acceptance flow before screens: launch empty, create named quest, complete, undo, relaunch and confirm persistence. Capture initial failing run once simulator runtime is available.
- [ ] Build SwiftUI flow against the documented domain interface, reuse approved artwork and palette, keep art selection anonymous visually, expose Monday grace choice.
- [ ] Generate Xcode project with XcodeGen and build generic iOS Simulator without signing.
- [ ] Run UI acceptance on installed runtime. Capture create, achievement, list, art picker screenshots. Check animations with reduced motion.
- [ ] Independent review of spec coverage and code quality; resolve findings with targeted RED/GREEN tests.

## Finish

- [ ] Record fresh test/build results and remaining device-signing step in README/development log.
- [ ] Keep work on `codex/ios-foundation`, do not push or submit to App Store Connect.
