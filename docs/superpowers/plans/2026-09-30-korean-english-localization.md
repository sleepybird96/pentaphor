# Korean and English Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Execution method already selected: direct implementation followed by independent review.

**Goal:** Ship Korean and English PENTAPHOR without changing user data, period rules, or purchase rights.

**Architecture:** Use Apple bundle localization with explicit bundle ownership. Use `en.lproj` / `ko.lproj` `Localizable.strings` and `Localizable.stringsdict` in both the app and Core; this supports existing plain `swift test` and Xcode builds without a catalog compilation dependency. A small Foundation lookup boundary supports deterministic locale tests; UI code resolves application-owned strings while Core owns its domain labels and errors.

**Tech Stack:** Swift 6, SwiftUI, Foundation, Swift Package Manager, XcodeGen, XCTest/Swift Testing, StoreKit 2, existing Python TestFlight tooling.

**Spec:** `docs/superpowers/specs/2026-09-30-korean-english-localization-design.md` (user approved 2026-09-30).

## Global Constraints

- Work in `/Users/gsang2/dev/pentaphor`; preserve history, bundle ID, team, credentials location, and existing user data. Use a `codex/` feature branch in this canonical checkout; do not resume historical checkouts.
- Support Korean and English; English development fallback; system/app language settings choose the language. No third-party localization SDK or persisted in-app language preference.
- Preserve PENTAPHOR, CHALLENGE, STACK YOUR PROGRESS and intentional English display accents. Stat names: Stamina / Knowledge / Perseverance / Charm / Courage.
- Never translate existing user quest names, notes, nicknames, Codable values, art IDs, or backup schema. StoreKit `displayPrice` remains authoritative.
- Preserve stored time zone, Monday 00:00 week start, Monday 09:00 previous-week cutoff and recap release, notification quota suppression, and earned points.
- Keep Korean information/data notices polite and other product copy friendly. Preserve art-only selection without forced quest naming or visible art-name captions.
- Internal TestFlight Personal delivery is authorized; public review submission, legal agreements and tax/bank entry are not part of this plan.

## Review Focus

- Language preference differs from region (English in Korea; Korean in the US): text follows chosen language while dates/numbers respect formatting locale (Tasks 1, 3).
- User text contains Korean, emoji, `%`, or resembles a localization key: it stays byte-for-byte unchanged (Tasks 2, 3).
- Same notification ID/date exists with an old-language body: synchronize replaces content without duplicate alerts or resurrecting completed quotas (Task 2).
- English stat names and accessibility text exceed Korean widths: radar, long buttons and large text remain usable (Tasks 3, 4).
- Archived/restored quests and historical backups survive language changes with identical identities, values, totals and week boundaries (Tasks 1, 4).

## Task 1: Deterministic bundle lookup and Core localization

**Files:** Create `Packages/PentaphorCore/Sources/PentaphorCore/Localization.swift`; create `Resources/en.lproj/Localizable.strings`, `Resources/ko.lproj/Localizable.strings` and matching `Localizable.stringsdict` under the same source target. Modify `Packages/PentaphorCore/Package.swift`, `Domain.swift`, `ExperiencePreferences.swift`, `BackupArchive.swift`, `QuestReminders.swift`. Create `Packages/PentaphorCore/Tests/PentaphorCoreTests/LocalizationTests.swift`; extend `QuestReminderTests.swift`.

**Interfaces:** `public struct LocalizedText: Sendable` holds a resource Bundle and resolved language; `init(bundle: Bundle, preferredLanguages: [String], locale: Locale)`; `func string(_ key: String) -> String`; `func format(_ key: String, _ arguments: CVarArg...) -> String`. Language selection uses Bundle preference matching against en/ko, then en. Formatting locale is independent of chosen language; use the selected lproj bundle for lookup, including plural dictionaries. `public enum CoreLocalization` exposes `static var current: LocalizedText` and `static func text(preferredLanguages: [String], locale: Locale) -> LocalizedText` with `.module`. `Stat.title` and errorDescription stay source-compatible and delegate to current resources. Add `localeText: LocalizedText = CoreLocalization.current` as the final defaulted argument of `QuestReminderPlanner.plan`.

- [ ] Write tests `resolvesLanguageSeparatelyFromRegion`, `unsupportedLanguageFallsBackToEnglish`, `coreLabelsAndErrorsAreTranslated`, `reminderPluralCounts`, `localizedPlanningPreservesScheduleAndUserTitle`. Assert ko/en labels, preference list `["fr", "ko"]` resolves ko, `["fr"]` resolves en, counts 0/1/2/99 use correct plural forms, and a title `독서 📚 100%` is unchanged across identical planned IDs/dates/quest IDs.
- [ ] Run `swift test --package-path Packages/PentaphorCore --filter LocalizationTests` and new reminder tests before implementation; record the expected missing-API failures.
- [ ] Implement the lookup boundary and resources; set `defaultLocalization: "en"` and `.process("Resources")` in Package.swift. Keep resource lookup separate from formatting locale. Cover all current Core Korean product strings. Do not change model raw values or period arithmetic.
- [ ] Run full `swift test --package-path Packages/PentaphorCore`; require all tests pass, adjusting any old Korean text assertions to explicit language rather than global defaults.
- [ ] Commit Core localization and tests.

## Task 2: App resources, art presentation, and reminder reconciliation

**Files:** Create `Pentaphor/App/AppLocalization.swift`, `Pentaphor/Resources/en.lproj/Localizable.strings`, `Pentaphor/Resources/ko.lproj/Localizable.strings` and matching `.stringsdict`; extract art models from `Pentaphor/Views/DesignSystem.swift` into `Pentaphor/Views/ArtCatalog.swift`. Modify `Pentaphor/App/QuestReminderService.swift`, `Pentaphor/App/PentaphorApp.swift`, `project.yml`, generated `Pentaphor.xcodeproj/project.pbxproj`. Create `PentaphorTests/LocalizationTests.swift`, `PentaphorTests/ArtLocalizationTests.swift`; extend `PentaphorTests/QuestReminderServiceTests.swift`.

**Interfaces:** `enum AppLocalization` provides `static var current: LocalizedText` using Bundle.main and the app's resolved preferred localizations, plus `static func text(preferredLanguages: [String], locale: Locale) -> LocalizedText` for tests. `Art` keeps its decoded category as a stable category token; localized presentation is `func displayLabel(using: LocalizedText) -> String`, `func displayCategory(using: LocalizedText) -> String`, `func matches(_ query: String, using: LocalizedText) -> Bool`. Keys `art.<id>.label`, `art.<id>.keywords` and category keys cover all 60 entries. Add defaulted `localization: @escaping () -> LocalizedText = { CoreLocalization.current }` to the reminder service initializer and pass it to the planner. App-origin error/test-notification copy uses AppLocalization.

- [ ] Add failing tests for all 60 localized art labels/categories, English searches `swim` and `read`, Korean search `수영`, and unchanged IDs/filenames. Validate every supported catalog entry has resources rather than accepting a raw key fallback.
- [ ] Add reminder test `languageChangeReplacesPendingContentWithoutChangingIdentity`: same state/clock, first ko then en through injected provider; expect same IDs/dates, changed body, no extra IDs. Complete quota, synchronize again, and verify completed-period alerts stay absent.
- [ ] Run new tests with `xcodebuild test -project Pentaphor.xcodeproj -scheme Pentaphor -destination 'platform=iOS Simulator,id=B3147374-5BC7-48E0-952D-C3E55BE423C3' -only-testing:PentaphorTests/LocalizationTests -only-testing:PentaphorTests/ArtLocalizationTests -only-testing:PentaphorTests/QuestReminderServiceTests`; record failures.
- [ ] Implement resources/lookup/art and pass language through reminder planning. Retain existing state/foreground synchronization and full pending-content comparison; add locale-change notification synchronization only for a live process change. Configure English development language and en/ko regions in project.yml; regenerate with `xcodegen generate` and inspect project diff for signing or scheme drift.
- [ ] Run the same test command; require pass. Verify app and package bundles both contain en/ko localizations.
- [ ] Commit resources, art presentation, reminder integration and tests.

## Task 3: All screens, accessibility, and locale formatting

**Files:** Modify all product views in `Pentaphor/Views/` (AchievementView, BackupSettingsView, BrandCopy, ChallengePaywall, ChallengeUnlockView, DesignSystem, IntroductionView, JournalViews, LaunchLoadingView, ParameterRadar, QuestEditor, QuestHome, QuestReminderFields, SettingsView, WeeklyRecapView). Modify Korean product strings in `Pentaphor/App/` including backup and purchase services and launch errors. Add `Pentaphor/Views/LocalizedDisplayFormat.swift`; extend `PentaphorTests/LocalizationTests.swift`. Add `scripts/check_localizations.py` and `scripts/tests/test_localizations.py`.

**Interfaces:** `enum LocalizedDisplayFormat` provides `static func day(_ date: Date, locale: Locale, timeZone: TimeZone, includeYear: Bool) -> String` using localized date templates with the supplied stored time zone, and `static func weekday(_ weekday: Int, locale: Locale) -> String` preserving Sunday=1 notification storage. Existing raw user String inputs remain verbatim. Whole translated sentences use positional placeholders and stringsdict plural forms; do not concatenate translated grammar fragments.

- [ ] Add failing formatting/resource checks for English/Korean dates at a stored-time-zone midnight boundary, weekday mapping, counts 0/1/2/99, and user nickname `설정 100% 📚` interpolated without localization. Checker tests reject missing peer keys and incompatible format placeholders and accept legitimate plural dictionaries; coverage does not claim that regex proves all UI is translated.
- [ ] Run `python3 -m unittest discover -s scripts/tests -p test_localizations.py` and the LocalizationTests target; record failures.
- [ ] Replace all user-facing Korean literals at presentation boundaries; use English semantic resource keys and en/ko values. Keep static resolved strings computed when language can change, and keep brand-only constants constant. Translate backup/purchase errors without altering underlying operations. Use localized category display with stable filtering, an independent All sentinel, and bilingual search keywords.
- [ ] Replace fixed ko_KR/calendar display formatting with LocalizedDisplayFormat, including recap/journal and reminder weekdays. Keep backup filenames stable machine format. Localize dynamic totals, progress accessibility, nickname headings, and quota sentences. Keep transaction price from StoreKit, without a hardcoded currency substitution.
- [ ] Run checker tests, `python3 scripts/check_localizations.py`, and app unit tests. Review `rg -n '[가-힣]' Pentaphor Packages/PentaphorCore/Sources` results manually: allow translation resources, preserved catalog metadata and DEBUG sample user data; resolve production UI leftovers.
- [ ] Commit localized UI and validation tooling.

## Task 4: Bilingual end-to-end tests, preservation, and visual review

**Files:** Create `PentaphorUITests/LocalizationFlowTests.swift`; modify `PentaphorUITests/PentaphorUITests.swift`, `PentaphorUITests/ChallengePurchaseFlowTests.swift`; extend Core LocalizationTests for legacy data preservation.

- [ ] Add English UI tests with standard `-AppleLanguages (en) -AppleLocale en_US` launch arguments: create/edit/complete a Unicode quest, open stats/history, inspect settings/backup and CHALLENGE purchase/restore labels. Add English recap scenario using existing DEBUG fixture. Relaunch without reset in Korean and verify the same user quest and points. Add unsupported preferred language fallback test at the app boundary.
- [ ] Make existing Korean UI tests pass explicit `-AppleLanguages (ko) -AppleLocale ko_KR` on every launch/relaunch; do not change business assertions just to pass. Add Core test that encodes a state/backup, resolves both languages and reopens it, asserting equal stored state, totals and Monday cutoff outcomes.
- [ ] Run the new UI tests before polishing UI; record untranslated/truncated failures. Fix layout only where English or large text is unusable; retain the established visual design.
- [ ] Run full Core and app native/UI suite. Run `PentaphorStoreKitTests` separately to verify price and purchase behavior remain intact. Capture ko/en screenshots for onboarding, quest editor, radar, recap, settings and paywall, including large accessibility text; inspect for overlap/cutoff. Attach artifacts outside the repo's build output.
- [ ] Commit bilingual regression tests and necessary layout fixes.

## Task 5: Store copy, independent review, and internal delivery

**Files:** Create `docs/app-store/en-US-metadata.md`; update `docs/challenge-storekit.md`, `docs/testflight-internal.md`, and this plan's completion checkboxes.

- [ ] Draft English app description, subtitle, promotion copy and keywords from implemented behavior. Draft CHALLENGE name `CHALLENGE Lifetime Unlock` and description `Permanently unlock unlimited active quests and parameter growth with one purchase.` Validate field lengths before entry; do not invent support/privacy URLs or claims about cloud sync.
- [ ] Inspect App Store Connect's existing app-localization fields and save English app/IAP localization where required factual fields are available. Preserve Korean entries, pricing and availability. Record any concrete missing fields/session blockers; do not submit for public review.
- [ ] Request one independent final review covering spec, diff, tests, locale fallback, resource packaging, user data preservation, notifications, StoreKit and UI layout. Verify each finding and fix with a failing regression test when applicable; rerun affected checks.
- [ ] Run `git diff --check` and the localization checker, then `python3 scripts/testflight.py deploy` using the existing credential-aware Python environment. This runs the required regression tests and creates a fresh archive/build. Do not bypass test failures or re-upload on a processing timeout.
- [ ] Verify Apple processing and Personal READY. On timeout, use `python3 scripts/testflight.py status --version VERSION --build BUILD --wait`. Record exact build and logs, distinguish upload from availability, and report any external blocker accurately.
- [ ] Commit verified results, integrate the feature branch into canonical main without discarding user changes, and push. Verify clean status and matching remote/local commit. Report supported languages, preservation guarantees, verified tests, TestFlight build and outstanding store-only work.

## Plan self-review

All design sections map to Tasks 1–5. All five review risks have explicit tests. Language selection and formatting locale are independent; lookup bundle ownership is explicit. Stable user data/art IDs and reminder identities are preserved. Current project remains iOS17/Swift6; localization resources use standard .lproj processing in both CLI and Xcode. No new legal, external distribution, dependency or credential scope is introduced.

## References

- Apple: https://developer.apple.com/documentation/xcode/localizing-package-resources
- Apple: https://developer.apple.com/documentation/xcode/preparing-your-apps-text-for-translation
- Apple: https://developer.apple.com/documentation/Xcode/localizing-and-varying-text-with-a-string-catalog (plural and localized text behavior; this plan uses equivalent .strings/.stringsdict resources for CLI compatibility).
