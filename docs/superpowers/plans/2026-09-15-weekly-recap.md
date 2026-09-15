# Weekly Recap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Present the latest unseen closed week's actions and parameter growth on launch/foreground.
**Architecture:** Pure historical recap builder plus persisted acknowledgement, a main-actor presentation coordinator, and a SwiftUI animated reward screen. Existing calendar/engine remain authoritative.
**Tech Stack:** Swift 6, SwiftUI/iOS17+, SwiftData, Swift Testing/XCTest.
**Spec:** docs/superpowers/specs/2026-09-15-weekly-recap.md

## Global Constraints
- Existing version1 data, bundle app.pentaphor.personal, team NX53XT8XMU; internal Personal only.
- Saved timezone, Monday00 week rollover and Monday09 recap cutoff. No re-awarding points or record writes during display.
- Root alone runs simulator tests/xcodegen/deploy; agent ownership is disjoint.

## Task 1: Core historical recap and acknowledgement
Files: Packages/PentaphorCore/Sources/PentaphorCore/{WeeklyRecap.swift,Domain.swift,QuestEngine.swift,StateRepository.swift}; Tests/PentaphorCoreTests/WeeklyRecapTests.swift.
Interfaces: all exact core definitions in spec.
- [x] Add failing tests. Concrete Seoul cutoff Sep14 2026 09:00 = Sep14 00:00Z; 08:59:59 must still return week Aug31, cutoff returns week Sep7. Include weekly grace with month/once recorded on Monday assigned to new week, changed rewards, weekly/month streak bonus, voided/deleted records, latest-only, empty and monotone acknowledgement.
- [x] Run `swift test --package-path Packages/PentaphorCore --filter WeeklyRecapTests` RED with interface stubs, then implement grouping by effective week and historical bonuses.
- [x] GREEN focused/full core; report evidence/diff for independent review. No simulator or commits.

## Task 2: Recap visual
Files: Pentaphor/Views/WeeklyRecapView.swift only.
Consumes WeeklyRecapView initializer/core exact spec. Reuse QuestArt/ParameterRadar/Palette/PrimaryButton.
- [x] Lay out dark game reward result with date/count/activities, gains, bonus and animated radar. IDs `recap.title`, `recap.actions`, `recap.gains`, `recap.done`; root tests missing `recap.title` on current app before integration.
- [x] Ordered reveal with ~2-second total animation, task cancellation checks, immediate settled display under simplified/ReduceMotion, accessible scrollable buttons and no point writes. Root owns screenshot/OS validation.

## Task 3: Lifecycle and presentation integration
Files: Pentaphor/App/WeeklyRecapCoordinator.swift; Pentaphor/{App/PentaphorApp.swift,Views/QuestHome.swift,Views/JournalViews.swift}; PentaphorTests/WeeklyRecapCoordinatorTests.swift; PentaphorUITests/PentaphorUITests.swift; optional isolated DEBUG fixture source.
- [x] Native coordinator RED: pending check at launch/foreground, busy deferral, no duplicate acknowledged reports, failed save retains presentation/no point changes. `requestCheck()`, `presentIfPossible(engine:now:isBusy:)`, `show(_:)`, `finish(store:at:) throws`; state `presentation: WeeklyRecap?`.
- [x] Implement coordinator and hook first appearance/foreground. Respect existing sheets/alerts and pending notification editor; drain after dismiss. History button opens latest closed report through coordinator.
- [x] UI RED missing recap; add isolated DEBUG seeded historical fixtures and injected recap clock for cold/foreground acceptance without changing OS/device records. GREEN confirm acknowledgement/relaunch and explicit replay, count and totals stable.

## Task 4: Review, verification and delivery
- [x] Independent scoped core/UI/coordinator review; address concrete bugs with regressions.
- [x] Generate Xcode project, focused native/UI GREEN and screenshot QA, then default `python3 scripts/testflight.py deploy` full verification/archive/upload and exact Personal READY.
- [x] Update development log/testflight docs and commit intended files only. Leave unrelated untracked art files untouched.

## Final evidence
Core RED→GREEN: 11 new cases, full core 91. Coordinator RED→GREEN: 5 cases including failed save and a newer foreground request while another report is open. UI cold/relaunch/replay, foreground editor and History dialog deferral passed; screenshot QA covered hero/radar and gain/bonus/quest arts. Independent review approved the final fixes. Full default delivery passed 150 tests and signed archive, uploaded 1.0 (7) at 07:35:19 UTC, then returned READY / exit 0 for exact Personal internal build. Artifacts: `~/Library/Developer/PentaphorDeliveries/20260915-072448-raedwkkh/`; app commit `b32ea63`.
