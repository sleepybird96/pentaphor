# Onboarding, preferences, and progress identity

User-approved identity: **STACK YOUR PROGRESS.** / **작은 행동을 쌓아, 나를 키우다.**

## Scope
- First-launch introduction: brand and animated example, optional nickname, explanation of quests → up to 2 points → five parameters. Allow skipping directly to the app, and choosing first quest creation or exploration at the end.
- Nickname: local, optional, trimmed, at most 20 characters, no newline. Used in parameter heading; editable/clearable in settings. No account or network.
- First creation help: explain free art choice, weekly/monthly targets and reward allocation; show a clearly labelled reward preview that cannot create records or points. Mark help complete only when an actual first quest saves. Existing users do not get this help automatically.
- Settings from header gear: nickname, haptics (default on), simplified celebration (default off), read-only saved time zone and Monday 00:00 / Monday before 09:00 rule, replay introduction, parameter/record rules, app version and local-data information. No empty links or inactive future controls.
- Replay is read-only, can be closed, does not clear nickname/preferences or award points. Existing data without preferences bypasses first launch, including an empty legacy store.
- Use slogan in first launch, settings identity and empty quest state. Header uses compact progress identity. Keep own-pace reassurance in goal-setting context. Achievement and history copy emphasize accumulated actions.
- Retain ivory/ink/teal/gold palette, bold italic English headlines and action art. All controls have 44pt targets; new screens scroll at large text sizes. System Reduce Motion always wins; settings can additionally simplify effects. Turn off haptic feedback when disabled.

## Persistence and failure behavior
Add optional `preferences` to v1 AppState, retaining old decoding and all quest/history snapshots. Fresh QuestStore creates explicit defaults. Missing preferences means established user (onboarding and first-quest help complete). Preference edits use the existing transactional save and only publish on success. Invalid nickname produces a friendly error, without changing state. Replay does not mutate state. Dismissing unfinished first quest keeps help available. Intro completion saves nickname and completion flag atomically before navigating away.

## Acceptance
Core: fresh/legacy distinction, nickname normalization/validation/clearing, preference disk reopen, save rollback, untouched quest/history/timezone, motion policy.
Native: complete intro into real first-quest editor, skip nickname/tour, zero points from previews, no reappearance after relaunch, editable settings persistence, read-only replay, all existing five UI flows continue passing.
Build for simulator and signed iOS device. Inspect introduction, settings, guided creation screenshots. No device reset, installation, push, or publication.

Backup/restore, reminders and recap remain the separately discussed next phase.
