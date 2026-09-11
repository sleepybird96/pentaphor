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
