# iOS foundation development log

Spec: `docs/superpowers/specs/2026-09-11-ios-foundation-design.md`
Plan: `docs/superpowers/plans/2026-09-11-ios-foundation.md`

- Baseline: asset/design-only repository, no existing app code or tests. Xcode 26.3 / Swift 6.2.4 / XcodeGen 2.45.4 available. No simulator runtime installed; downloading iOS runtime.
- Working branch: `codex/ios-foundation`. New repository has no base commit; implementation stays in the shared checkout so the existing untracked user artwork remains available. No existing application behavior is overwritten.
- User decision: Monday 00:00 begins the new week; explicit previous-week recording permitted until 09:00, exclusive.
- First-version policy: freeze initial aggregation timezone; target changes after activity start next period; cadence changes only before first activity. These keep historical completion meaning stable.

## TDD evidence

Evidence is appended after actual runs, not inferred from test existence.
