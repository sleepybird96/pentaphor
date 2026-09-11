# Native UI implementation report

## Scope

Implemented SwiftUI iPhone presentation in `Pentaphor/`, UI acceptance in `PentaphorUITests/`, and XcodeGen configuration / generated `Pentaphor.xcodeproj`. Shared core owned separately in `Packages/PentaphorCore`.

- Home: empty first use; separate weekly/monthly lists, projected progress, create/edit, archive access, tabs.
- Editor: custom name, anonymous art selection, 1–99 goals, weekly/monthly cadence, up to two reward points including zero. Uses the last effective target entry so unrelated edits preserve queued changes. Explains history-sensitive target/cadence policy.
- Art picker: all 60 approved entries, category filters, search against accessible names/keywords; no visible art labels. Selection preserves quest name.
- Achievement: approved dark/ivory/teal/gold composition, large matching artwork, phased art→rewards→spring pentagon growth, haptic, immediate final state when Reduce Motion is active, undo after successful transaction.
- Stats, record history with undo confirmation, archive/restore. Stored aggregation time zone shown on parameter screen.
- Weekly grace choice calls the core calculator at interaction time; previous week is explicit, offered only Monday before 09:00 for existing prior-week quests. Completion validates again through core.
- Load failures remain visible with retry. Transactions publish only after save succeeds through QuestStore.

## Assets

`Pentaphor/Resources/art-catalog.json` derives directly from `design/quest-art-data.js` (60 entries). The Xcode resources phase references only `assets/quest-art/*.png` through a filtered source group; no duplicate source raster files or image generation. Runtime display decoding uses bounded thumbnail dimensions and a 48MB NSCache; source PNGs remain untouched, including revised music/pet-feeding/dishwashing files. Uses native Avenir Next Condensed Heavy Italic and system typography as the offline fallback to the approved web study's fonts.

## Test-first evidence

Wrote two XCTest UI acceptance cases before native production screens: create→complete→undo→relaunch and custom-name preservation across art selection plus archive/restore. The first attempted run was:

```
xcodebuild test -project Pentaphor.xcodeproj -scheme Pentaphor \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -destination-timeout 1 CODE_SIGNING_ALLOWED=NO
```

2026-09-11 07:37 UTC: exit 70; no available simulator/runtime. Output `/tmp/pentaphor-ui-red.log`: “Unable to find a device matching the provided destination specifier”. This is an environmental block, **not semantic RED**. Production implementation proceeded under the delegated instruction to distinguish this block rather than claim a failing assertion.

First generic simulator build at 07:43 UTC reached SwiftCompile; it failed only because the concurrently developed `QuestStore` had not yet been added. `/tmp/pentaphor-ui-build.log`. Runtime iOS 26.3.1 subsequently installed; iPhone 17 Pro B3147374-5BC7-48E0-952D-C3E55BE423C3 booted successfully.

## Test isolation

Only DEBUG builds recognize `--ui-testing`, which selects `Application Support/UITestStore/acceptance.store`. Only accompanying `--reset-test-store` removes that isolated directory. Relaunch without reset preserves the same test database. Production has no seed data and no reset path. The tests exercise real SwiftData via QuestStore, not mocked state.

## Final verification

Normal-motion simulator acceptance passed: 2 tests, 0 failures in 40.649 seconds at 07:49:45 UTC (`/tmp/pentaphor-ui-green.xcresult`). Generic simulator build passed (`/tmp/pentaphor-ui-final-build.log`). Final revised packaging and Reduce Motion acceptance are documented below. No signing account changes, network runtime dependencies, commits, uploads, or publishing performed.

### Real simulator persistence RED

Once runtime and core compile-time APIs existed, ran the create/complete/undo/relaunch test against the intentionally nonpersistent core repository/store implementation. Command:

```
xcodebuild test -project Pentaphor.xcodeproj -scheme Pentaphor \
  -destination 'platform=iOS Simulator,id=B3147374-5BC7-48E0-952D-C3E55BE423C3' \
  -only-testing:PentaphorUITests/PentaphorUITests/testCreateCompleteUndoAndRelaunchPreservesQuest \
  -resultBundlePath /tmp/pentaphor-ui-first.xcresult CODE_SIGNING_ALLOWED=NO
```

2026-09-11 07:47:20 UTC: **1 test, 1 expected assertion failure**, 30.542s. Creation, completion, achievement, undo, and projected 0/3 count all passed. Relaunch failed at test line 32 because the quest was absent, demonstrating the missing disk persistence. `/tmp/pentaphor-ui-first.log`, `/tmp/pentaphor-ui-first.xcresult`. This is semantic RED for persistence integration; the UI presentation itself had already been implemented following the initial environment block. The core owner received this persistence failure during the durable storage implementation sequence.


### Review fixes and bundle inspection

All native copy follows the user's established casual Korean tone (반말), including errors, edit-policy explanations, history and archive text. No copy-only tests were introduced. PNG resources now use an XcodeGen `includes: ["*.png"]` group and flat Bundle lookup. Inspected the built app: exactly 60 PNG filenames match the catalog; no source manifests, generation prompts, HTML, or `.generation` content. No source PNG was edited.

Screenshot QA improved the status-bar contrast on the dark achievement screen, switched display type to native Avenir Next Condensed Heavy Italic, separated radar labels from reward chips, dimmed disabled allocation buttons, and made the art picker explicitly full height. Native form scrolling keeps longer content and large text accessible; the acceptance uses the persistent toolbar Save control with the keyboard visible.

### Reduce Motion verification

Compiled a temporary simulator UIKit probe (`/tmp/pentaphor-motion-probe.swift`) that prints `UIAccessibility.isReduceMotionEnabled`. It reported false initially; after `simctl spawn … defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES`, the native API reported true. Final acceptance runs under that actual system setting. This does not use a production launch-argument override of Reduce Motion. The original false setting will be restored after the run.

### Final results

- Normal-motion XCTest: **2 passed, 0 failures**, 40.649s (`/tmp/pentaphor-ui-green.xcresult`, completed 07:49:45 UTC).
- Final packaging + real Reduce Motion XCTest: **2 passed, 0 failures**, 40.888s (`/tmp/pentaphor-ui-final.xcresult`, completed 07:53:21 UTC). Assertions include zero total parameters after undo/relaunch and retained voided history. System Reduce Motion restored to its original false value and confirmed with UIKit afterward.
- Final generic iOS Simulator build (arm64 + x86_64), after cadence-specific bonus/period-neutral progress copy: **BUILD SUCCEEDED**, 07:55:11 UTC (`/tmp/pentaphor-ui-verified-build.log`). `CODE_SIGNING_ALLOWED=NO`. Only Xcode's expected “Metadata extraction skipped. No AppIntents.framework dependency found” warning.
- `python3 scripts/native_assets.py verify <built Pentaphor.app>`: **PASS**, exactly 60 approved PNGs and catalog; no source/generation metadata. Xcode performs its normal PNG resource optimization, so built PNG byte hashes need not match source PNG byte hashes; source files are not modified.
- `python3 scripts/native_assets.py generate` reproducibly regenerates the catalog from approved design data.

Final screenshot files (exported from passing tests, visually inspected):

- `/tmp/pentaphor-native-screenshots/01-create.png`
- `/tmp/pentaphor-native-screenshots/02-home.png`
- `/tmp/pentaphor-native-screenshots/03-achievement.png`
- `/tmp/pentaphor-native-screenshots/04-art-picker.png`
- `/tmp/pentaphor-native-screenshots/05-stats-after-undo.png`

Root integration: copy these PNGs to the desired final artifact directory. No physical-device signing/install or App Store submission was performed. Tests run on iPhone 17 Pro with iOS 26.3.1; minimum deployment target builds as iOS 17.0.

### Final midnight-boundary review

The list refreshes on a 30-second TimelineView. Review found that using its previously rendered period for previous-week eligibility could hide the explicit choice on a tap immediately after Sunday→Monday midnight. The UI now captures one fresh `Date()` in the tap handler and calls `QuestEngine.canRecordPreviousWeek(for:at:)`; no rendered progress period participates in this decision. The core owner added a regression test for the eligibility projection. The preceding full UI run against final storage still passed (2 tests, 0 failures, 41.388s at 07:57:11 UTC, `/tmp/pentaphor-ui-integrated.xcresult`); a final run below includes the midnight projection change.


### Final integration after midnight fix — complete

- `xcodebuild test -project Pentaphor.xcodeproj -scheme Pentaphor -destination 'platform=iOS Simulator,id=B3147374-5BC7-48E0-952D-C3E55BE423C3' -resultBundlePath /tmp/pentaphor-ui-release-check.xcresult CODE_SIGNING_ALLOWED=NO`: **2 passed, 0 failures**, 42.133s at 08:09:56 UTC. Log: `/tmp/pentaphor-ui-release-check.log`. This run includes the core's final 33-test implementation and the tap-time previous-week eligibility API.
- `xcodebuild build -project Pentaphor.xcodeproj -scheme Pentaphor -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`: **BUILD SUCCEEDED**, 08:10:34 UTC. Log: `/tmp/pentaphor-ui-release-build.log`.
- Asset packaging verification repeated successfully against that final build.
- Launched `app.pentaphor.personal` without test arguments after testing. Visually confirmed the empty production first-use screen. Simulator is left in that normal app state. Final first-use capture refreshed at `/tmp/pentaphor-native-screenshots/00-first-use.png`.
- Root copied the six reviewed captures into `docs/screenshots/`. No remaining native UI integration work.
