# Current quest target edits

User reports editor 14 while list remains 7. Cause: existing engine defers edited targets to next period once any record exists; list reads frozen completion target. User requests the edited value be reflected now.

- Weekly/monthly target edits apply to current calendar period immediately, whether it has live or voided records. Supported target remains 1...99, one-time exactly 1.
- Preserve older periods' completion targets, rewards, counts and identity. Update current-period target snapshots (including voided) consistently and replace obsolete future target changes with the new current change. Already awarded action rewards remain fixed; current goal qualification and derived streak bonus recalculate. Prior-week grace remains its original target.
- Editor, list, planner and recap must agree through the engine target authority. Change editor help to state current period application. Existing previously scheduled next-period changes stay intact until user saves an edit; saving 14 again applies now.
- Regression RED→GREEN: weekly and monthly 7→14 with activity, lower target, voided-only activity, future schedule repair, closed history and grace preservation, bonus/reminder qualification. Update legacy next-period assertions to new approved behavior. Root adds native UI acceptance that completes a quest, changes target to 14, verifies list and relaunch.
