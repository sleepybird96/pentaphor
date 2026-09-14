# Onboarding and Preferences Implementation Plan

> Execute inline with executing-plans and test-driven-development; preserve the current user-facing development checkout.

**Goal:** Introduce PENTAPHOR through accumulating progress and provide useful local preferences.
**Architecture:** Optional Codable preferences in the existing transactional AppState. SwiftUI onboarding and settings consume the same QuestStore. Existing stores resolve to established-user defaults.
**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XCTest, iOS 17+.
**Spec:** docs/superpowers/specs/2026-09-14-onboarding-and-preferences.md

## Global Constraints
- Identity: STACK YOUR PROGRESS. / 작은 행동을 쌓아, 나를 키우다.
- Preserve v1 data, signing team NX53XT8XMU and bundle app.pentaphor.personal.
- No notifications, backup, account, network or distribution work in this phase.

## Task 1: Persist experience preferences
Files: Domain.swift, ExperiencePreferences.swift (new), QuestEngine.swift, QuestStore.swift, StateRepository.swift; ExperiencePreferencesTests.swift (new).
- [x] Add failing acceptance against fresh initialization and saved JSON preferences. Legacy payloads contain no preferences and must remain readable.
- [x] Run `swift test --package-path Packages/PentaphorCore` and record RED.
- [x] Implement `ExperiencePreferences` with nickname, hasCompletedOnboarding, hasCreatedFirstQuest, hapticsEnabled, simplifiedEffects. Add `QuestEngine.preferences` and `updatePreferences(_:) throws` with trim/20-character/no-newline validation. Resolve nil using legacy defaults.
- [x] Persist through `store.transact { try $0.updatePreferences(candidate) }`; initial store explicitly sets fresh preferences. Repository rejects invalid saved nickname.
- [x] Verify disk reopening, legacy snapshots, rollback, nickname clearing and `usesSimplifiedEffects(systemReduceMotion:)` for both override sources.

## Task 2: Native introduction and settings
Files: IntroductionView.swift, SettingsView.swift, BrandCopy.swift (new); PentaphorApp.swift, QuestHome.swift, DesignSystem.swift, JournalViews.swift, AchievementView.swift, QuestEditor.swift; UI tests.
- [x] Add native test expecting `onboarding.start` on fresh launch and record missing-control RED.
- [x] Implement three scrolling intro pages, optional local nickname, final create/explore actions. Persist before routing. Read-only replay uses the brand and explanation pages only.
- [x] Route at QuestHome based on persisted onboarding flag, holding first-editor intent until intro dismissal. Keep existing home alive to preserve tab/editor state.
- [x] Add gear and settings with transactional bindings, nickname save/clear, meaningful local help and app information. No account or inactive controls.
- [x] Add first-creation guidance and reward preview. Save guide completion in the same transaction as quest creation. Use common `BrandCopy` values across main surfaces.
- [x] Apply haptic and reduced-animation choices to celebrations and previews; always honor system Reduce Motion.
- [x] Extend UI acceptance for nickname, skip, preview no-award, settings/replay/relaunch. Existing UI tests dismiss the real introduction through its public skip button only when present.

## Task 3: Verify and deliver
- [x] Run all core tests and all UI tests on iPhone 17 Pro simulator B3147374-5BC7-48E0-952D-C3E55BE423C3.
- [x] Signed build using separate device derived data. Keep simulator tests sequential.
- [x] Export/inspect screenshots; correct any new clipping, occlusion or inaccessible controls.
- [x] Update README and development log with actual results; `git diff --check`; commit only scoped files.
