# Current Target Edit Implementation Plan

> Execute with superpowers:subagent-driven-development, agent owns QuestEngine.swift, Domain.swift only if needed, QuestEditor.swift help only, and target-related core tests. Root owns UI tests/simulator/deploy.

**Goal:** Saving target14 immediately shows14 in the active list even after completing records.
**Architecture:** Keep target history and completion snapshots consistent for the editable current period; derived totals/planner use same authority.
**Spec:** docs/superpowers/specs/2026-09-15-current-target-edit.md

- [x] RED: create weekly/monthly target7, complete once, update14, require `engine.progress(for: engine.activeQuests[0], at: now).target == 14`. Verify lower targets, undo-only, next schedule repair, closed history, grace and bonus behavior.
- [x] Change current effective target and current completion target snapshots together; never change reward snapshots or prior periods. Editor copy states immediate current period application.
- [x] GREEN core incl. update old deferral-dependent tests; report exact commands/results. Root UI RED→GREEN edit-after-completion14/list/relaunch.
- [x] Scoped review then combined backup/target full TestFlight delivery; record evidence.

Verified 173 tests, signed archive, upload and exact Personal READY for 1.0 (8). Implementation commit `c517b7e`; detailed RED/GREEN and delivery evidence in docs/development-log.md.
