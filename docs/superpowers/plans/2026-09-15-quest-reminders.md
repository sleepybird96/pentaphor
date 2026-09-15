# Quest Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Remind on selected weekdays/time until the quest's current goal is met.
**Architecture:** Pure core planner derives one-shot notifications from persisted state. A serialized app coordinator reconciles UserNotifications; SwiftUI editor/settings expose configuration and permission.
**Tech Stack:** Swift 6, iOS 17+, SwiftUI, SwiftData, UserNotifications, Swift Testing, XCTest.
**Spec:** docs/superpowers/specs/2026-09-15-quest-reminders.md

## Global Constraints
- Preserve bundle app.pentaphor.personal, team NX53XT8XMU, version-1 data and saved record time zone.
- Default reminders off; saved changes only; no point or completion writes from notification delivery.
- Multiple weekdays, one time. 42 calendar days, at most earliest 60 reminder requests plus one test request.
- Use existing public Apple API TestFlight delivery, internal Personal only.

## Task 1: Core persistence and planner
Files: Packages/PentaphorCore/Sources/PentaphorCore/{QuestReminders.swift,Domain.swift,QuestEngine.swift,StateRepository.swift}; Tests/PentaphorCoreTests/QuestReminderTests.swift.
Interfaces: exact core types and planner signature in spec.
- [ ] Write tests with concrete dates: Mon Sep 14 2026 20:00 Asia/Seoul = 11:00Z; completing a weekly target removes that week's pending dates, preserves next week's dates. Include monthly, once, legacy decoding, invalid settings, DST, bounded deterministic scheduling.
- [ ] Run `swift test --package-path Packages/PentaphorCore --filter QuestReminderTests` RED.
- [ ] Add optional Quest reminder; validate in engine and repository. Enumerate calendar days, selected weekdays, strictly future fire dates and engine.progress at fire date; exclude archived/deleted/completed once; sort and prefix limit.
- [ ] Run focused and full core GREEN; record command/count and changed files for review.

## Task 2: Editor and settings UI
Files: Pentaphor/Views/{QuestEditor.swift,SettingsView.swift,QuestReminderFields.swift}; PentaphorUITests/PentaphorUITests.swift.
Consumes: QuestReminder and QuestReminderService from spec. Save uses `try engine.updateReminder(id: savedQuest.id, reminder: draftReminder)` within same transact as create/update.
- [ ] Add a UI test that enables reminders, chooses weekdays, saves, relaunches and checks persistence; canceling edits must preserve saved settings.
- [ ] Add optional toggle and 7 weekday buttons ordered Monday–Sunday, plus time picker. No weekday selection disables quest save while enabled. Persist only in save transaction.
- [ ] Expose OS permission status/settings action, real test notification, error and finite reservation notice in settings. Use existing visual styles and 44pt targets.
- [ ] Parent runs RED/GREEN native UI tests after integration; do not run concurrent simulator tests.

## Task 3: Platform scheduler and app lifecycle
Files: Pentaphor/App/{QuestReminderService.swift,ReminderNotificationCenter.swift,PentaphorApp.swift}; Pentaphor/Views/QuestHome.swift; PentaphorTests/QuestReminderServiceTests.swift.
Consumes core planner, exposes exact app interface from spec. Own center delegate early, persist selected route until store loads; editor routing validates active quest.
- [ ] Write native boundary tests for desired request replacement, muted completed goals, permission denial, errors/retry and coalesced overlapping synchronization. Observe real coordinator behavior, replace only OS scheduling with a controlled fake.
- [ ] Run native focused RED, implement coordinator with latest-state serialized drain. Owned-prefix removal only; add future requests and expose actual successful pending count. Ignore stale generation errors and converge on newest state.
- [ ] Hook persisted AppState changes and foreground/time changes; refresh permission and refill plan. Handle tapped quest IDs without creating records; notification test uses one separate 5-second request.
- [ ] Run native GREEN, integrate UI and verify system test notification through simulator.

## Task 4: Review, full verification and delivery
- [ ] Review core, UI and platform diffs against spec; address concrete findings with covering tests.
- [ ] Generate Xcode project, run `python3 scripts/testflight.py deploy` for all automation/core/native tests and signed build, then verify exact new build ready in Personal.
- [ ] Update docs/development-log.md with test evidence, local notification limitation and delivery status; commit only intended files.
