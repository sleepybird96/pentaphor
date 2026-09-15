# One-time quests and unified list

Approved: one-time quests join weekly/monthly quests in one list. No cadence section headers or new filters. Keep creation order; recurring rows retain their progress and cadence. One-time rows say “한 번”.

- Editor choices: 한 번 / 매주 / 매월. Default remains 매주, 3회. 한 번 has target 1 and no count stepper.
- One-time quests have no deadline or calendar reset. Completion awards configured 0–2 points exactly once, removes the quest from the active list, and preserves its definition and history. Undo restores eligibility and removes the reward; archive/deletion still take precedence.
- Retries using the same completion ID stay idempotent. A second live completion with a new ID fails atomically. After undo, a new completion is allowed.
- Only weekly/monthly goals earn system perseverance bonuses. One-time completion reports no streak or bonus; user-assigned perseverance points remain valid.
- First completion locks cadence even after undo, matching existing rules. One-time target must equal 1 on create/update/save/load. Invalid state cannot overwrite valid data.
- Existing version-1 weekly/monthly JSON remains readable without a migration or altered rewards. Reopening storage preserves completed/undone state.
- Empty home with existing completion history says “다음 걸음을 기다리는 중”; a fresh store retains the first-page message.
- History and achievement copy describe a completed one-time quest, never a recurring period or artificial lifetime date.
- Preserve weekly Monday 00:00 rollover and explicit previous-week entries before Monday 09:00 in the stored timezone, monthly rollover, target snapshots, launch animation, signing, and local data.
- No deployment or new reminders, due dates, filters, or ordering controls in this change.

Implementation: add Codable Cadence.once, represented internally by one canonical lifetime PeriodWindow (distantPast…distantFuture); never display its sentinel boundaries. Completion records determine finished status, not the archive flag. Reject malformed one-time targets, periods and multiple live records at repository boundaries.
