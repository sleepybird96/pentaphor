# iOS foundation development log

Spec: `docs/superpowers/specs/2026-09-11-ios-foundation-design.md`
Plan: `docs/superpowers/plans/2026-09-11-ios-foundation.md`

- Baseline: asset/design-only repository, no existing app code or tests. Xcode 26.3 / Swift 6.2.4 / XcodeGen 2.45.4 available. No simulator runtime installed; downloading iOS runtime.
- Working branch: `codex/ios-foundation`. New repository has no base commit; implementation stays in the shared checkout so the existing untracked user artwork remains available. No existing application behavior is overwritten.
- User decision: Monday 00:00 begins the new week; explicit previous-week recording permitted until 09:00, exclusive.
- First-version policy: freeze initial aggregation timezone; target changes after activity start next period; cadence changes only before first activity. These keep historical completion meaning stable.

## TDD evidence

Evidence is appended after actual runs, not inferred from test existence.

### Observed cycles — 2026-09-11

| Behavior | Semantic RED | GREEN |
| --- | --- | --- |
| Calendar boundaries, leap month, DST | 6 tests, 11 issues | Calendar suite passed in subsequent 10-test run |
| Quest validation | 10 tests, 21 issues | 10 tests / 2 suites passed |
| Completion snapshots, bonuses, undo and grace | 16 tests, 22 issues | 16 tests / 3 suites passed |
| Editing, archive/restore and history policy | 22 tests, 15 issues | 22 tests / 4 suites passed |
| SwiftData disk persistence and transactional store | 29 tests, 16 issues | 29 tests / 6 suites passed |
| Unknown art identifiers | 1 parameterized test, 4 issues | 30 tests / 6 suites passed |
| Malformed v1 data must not overwrite existing state | 10 parameter cases, 20 issues | 32 tests / 6 suites passed |
| Sunday screen → Monday tap grace eligibility | 1 test, 1 assertion failure | 33 tests / 6 suites passed |

The RED runs used missing behavior/stubs and failed assertions; compile errors were corrected before counting RED evidence. Individual full terminal logs were captured under `/tmp/pentaphor-*-red.log` and corresponding `*-green.log`; these temporary logs are not required to run the project.

Latest core run: `swift test --package-path Packages/PentaphorCore`, **33 tests in 6 suites passed**, 0 failures. Includes 10 malformed-state parameter cases, future-version-on-disk preservation, save-failure rollback, Seoul 00:00/09:00 boundaries, New York DST and leap February. Full final output: `/tmp/pentaphor-final-core.log`.

### Native integration evidence

UI acceptance was authored before production screens. The first attempt was blocked by the missing simulator runtime; this was an environment failure, not semantic RED. After installing the runtime, the real create→complete→undo→relaunch test failed on missing persistence against the deliberately nonpersistent repository stub (1 test, 1 assertion failure). With SwiftData implemented, both UI cases passed. See `native-ui-report.md` for exact commands and timings.

Both normal motion and actual system Reduce Motion were exercised. A native UIKit probe verified Reduce Motion enabled during the accessibility run and restored to its original disabled setting afterward. Six screenshots were visually inspected and copied to `docs/screenshots/`.

### Review resolutions

- Restricted runtime art IDs to the approved 60-entry catalog, with failing invalid-ID tests first.
- Added repository semantic validation for duplicate IDs, missing quest references, invalid names/art, reward bounds and target bounds; rejected writes preserve previous state.
- Verified unknown future on-disk versions reject both load and overwrite without changing the payload.
- Fixed a Sunday→Monday UI boundary: eligibility now receives the button tap time through a tested domain method rather than stale Timeline progress. Completion still validates time again when committing.
- Bundled only the 60 PNGs and native catalog. Source prompts, HTML and generation metadata are excluded.
- Unified native copy to casual Korean and made streak labels use weeks/months.

No developer account changes, remote push or App Store Connect upload performed. Development remains on `codex/ios-foundation`.

Final UI regression on the completed core and midnight fix: **2 tests, 0 failures**, 42.133 seconds at 08:09:56 UTC. `xcodebuild test` reported `TEST SUCCEEDED`; `/tmp/pentaphor-ui-release-check.xcresult`.

## 2026-09-14 — approved icon integration

Applied the user's approved 180-degree SHIFT emblem as both AppIcon and shared native BrandBar logo. Production image is opaque 1024×1024 with system-masked corners. Preserved the user's configured development Team in XcodeGen. Existing UI regression passed 2/2 (46.295s); simulator build and bundle verification passed. This changes visual assets and presentation only; domain rules and storage are untouched. Reviewed captures and generation provenance are in `design/brand/README.md`.

## 2026-09-14 — visible quest editing entry

User reported no discoverable way to edit a quest. Root cause: artwork/name already opened QuestEditor, but the row gave no visible indication of that action. Added a pencil + ‘수정’ chip inside the existing edit button and made its entire content rectangle tappable. The completion button remains a separate action.

Added real UI coverage: create a quest → find visibly labelled edit entry → open prefilled editor → rename existing quest → verify no completion or old-name duplicate → relaunch and reopen the saved edit. Initial filtered invocation selected zero tests and was not counted as validation. Full semantic RED ran 3 tests with 1 expected failure at the missing visible ‘수정’ assertion (`/tmp/pentaphor-edit-entry-red-full.xcresult`).

The first implementation exposed a second real bug: after relaunch, the first edit opened an empty creation form (asserted field value was the placeholder rather than the saved quest name). The test failed at the persisted edit prefill assertion (`/tmp/pentaphor-edit-entry-green.xcresult`). Replaced separate presentation boolean/selected quest state with one item-driven sheet payload, so editor identity and quest data arrive together on first and subsequent opens.

Final GREEN: 3 UI tests, 0 failures, 62.090s (`/tmp/pentaphor-edit-entry-final.xcresult`). Physical iOS signed build succeeded (`/tmp/pentaphor-edit-entry-device.log`). Visually checked `docs/screenshots/06-visible-edit-entry.png` and `07-edit-existing-quest.png`, including the prefilled editor after relaunch. The updated build is ready for an in-place Xcode Run on the user's phone; no physical-device data was reset or modified during testing.

## 2026-09-14 — quest notes

Spec: `docs/superpowers/specs/2026-09-14-quest-notes.md`. Optional multiline memo in create/edit, two-line list preview, local drafts with Save/Cancel, explicit empty-string clearing. Existing v1 JSON remains compatible through an optional `notes` field; the SwiftData model is unchanged.

Core semantic RED: 2 new tests failed with 4 assertions because notes were not assigned (`/tmp/pentaphor-notes-core-red.log`). Implemented create/update note assignment and clearing; full core suite passed **35 tests in 7 suites** (`/tmp/pentaphor-notes-core-green.log`). Includes a literal pre-notes v1 payload inserted into actual SwiftData storage, loaded, edited and reopened with history and points retained, plus multiline/emoji preservation and memo-only edits preserving completion snapshots.

UI semantic RED: 4 tests ran, with 1 expected failure because the memo input did not exist (`/tmp/pentaphor-notes-ui-red.xcresult`). Added the input and preview after observing this failure. Acceptance covers entering multiline notes, relaunching and reopening, cancelling an unsaved draft, and clearing a saved memo without completing the quest.

The first implemented UI run passed persistence and cancellation, but its clearing step assumed the reopened text cursor was at the end. Corrected the test to select all text before Delete. Final GREEN: **4 UI tests, 0 failures**, 95.450s (`/tmp/pentaphor-notes-ui-final.xcresult`). Signed physical iOS build succeeded (`/tmp/pentaphor-notes-device-build.log`). Reviewed memo input and list preview captures, saved as `docs/screenshots/08-quest-notes-editor.png` and `09-quest-notes-preview.png`. Ready for an in-place Xcode Run on the phone; no device installation or data reset was performed.

## 2026-09-14 — delete quests while keeping growth

User requested a red deletion entry below archive and explicitly chose to retain completion history and earned parameters. Spec: `docs/superpowers/specs/2026-09-14-quest-deletion.md`. Deletion persists an optional `deletedAt` marker, excludes the quest from active/archive lists, and blocks editing/restoring/new completions. Retained definitions preserve history labels and streak bonuses. Confirmation explains that the quest cannot be restored but history and parameters remain.

Core RED: 38 tests ran with 2 failing tests / 9 assertions against a no-op deletion interface (`/tmp/pentaphor-delete-core-red.log`). Implemented deletion and guards; full core GREEN: **38 tests in 8 suites**, including bonus preservation, disk reopen and failed-save rollback (`/tmp/pentaphor-delete-core-green.log`). UI RED: **5 tests, 1 expected failure** at the missing deletion entry (`/tmp/pentaphor-delete-ui-red.xcresult`).

Final UI GREEN: **5 tests, 0 failures**, 119.662s (`/tmp/pentaphor-delete-ui-green.xcresult`). Confirmed cancel, deletion, relaunch, exclusion from archive, retained history and 2 P; existing create/edit/memo/archive flows also pass. Visually checked the red entry below archive and confirmation copy in `docs/screenshots/10-quest-delete-entry.png` and `11-quest-delete-confirmation.png`. Physical iOS signed build succeeded (`/tmp/pentaphor-delete-device-build.log`). No user quest was deleted during development; UI tests use isolated simulator storage.

## 2026-09-14 — independent radar growth

User approved independent, nonlinear stat geometry with decorative guides and exact numeric totals. Spec: `docs/superpowers/specs/2026-09-14-independent-radar-growth.md`. Replaced the shared current-maximum normalization with `x / (x + 50)` for each axis, retaining the center footprint and outer margin. Added two decaying outward pulses only on increased axes; both polygon and markers use the same interpolated geometry. Reduce Motion displays the settled state. No persistence or points rules changed.

Core RED reproduced shrinking unaffected axes and missing pop/curve behavior: **42 tests, 22 failed assertions** (`/tmp/pentaphor-radar-red.log`). Implemented the fixed curve and animation geometry; core GREEN: **42 tests in 9 suites** (`/tmp/pentaphor-radar-green.log`). An initial native compile rejected an actor-isolated View's Animatable conformance; rendering the marker as an animatable Shape resolved the mismatch and shares the polygon's coordinate space.

Native UI regression: **4 passed, 1 failed** (`/tmp/pentaphor-radar-ui-final.xcresult`), with the existing notes test failing to clear its text via keyboard automation. Creation/completion/undo, editing, archive/restore, deletion with retained growth all passed. Inspected the achievement screenshot and saved `docs/screenshots/12-independent-radar-growth.png`; numeric labels and marker alignment are correct. Fresh physical iOS signed build succeeded (`/tmp/pentaphor-radar-device-build.log`, derived data `/tmp/pentaphor-radar-device-verification`).

Notes test investigation: some incremental runs executed older test behavior, so retried with fresh derived data. Keyboard selection, caret navigation and explicit deletion still did not reliably clear the fixture (`/tmp/pentaphor-radar-clean-notes.xcresult`, `/tmp/pentaphor-radar-notes-navigation.xcresult`, `/tmp/pentaphor-radar-notes-keys.xcresult`). Reverted experimental test changes; memo production code is unchanged. At this checkpoint the UI automation failure was unresolved, while radar geometry tests and signed build passed. The subsequent resolution is recorded below.

## 2026-09-14 — resolve memo UI automation failure

The user requested all tests pass. Strengthened the memo test to assert that the unsaved replacement is exactly the new text; the original cancellation assertion alone did not detect failed selection. With keyboard waits, the shortcut path failed **3/3 repetitions**: `Unsaved draftBring goggles\nEasy pace` remained instead of `Unsaved draft` (`/tmp/pentaphor-memo-keyboard-repeat.xcresult`). Disabling decorative border hit testing did not change the result and that experimental production change was reverted.

Replaced the unverified Command-A shortcut with the actual iOS edit menu: long-press the first text line, wait for the visible Select All menu item, select it, tap the software keyboard's Delete key, then assert an empty editor. This tests the user-visible editing path without bypassing storage or weakening assertions. Added keyboard readiness checks, an exact draft replacement assertion, and a second relaunch proving the cleared memo stays empty. The focused test passed all steps in **41.404 seconds** (`/tmp/pentaphor-memo-menu-check.xcresult`). Production app code is unchanged. Core verification passed **42 tests in 9 suites** (`/tmp/pentaphor-memo-core-final.log`).

Final complete UI suite: **5 tests, 0 failures**, 133.586s (`/tmp/pentaphor-all-ui-green.xcresult`), including the strengthened memo test passing again in 41.116s. All **47 tests** now pass across core and UI. Saved the native edit-menu capture as `docs/screenshots/13-memo-select-all.png`. This resolves the preceding failed UI check; no assertions were removed and no application storage or behavior was altered.
