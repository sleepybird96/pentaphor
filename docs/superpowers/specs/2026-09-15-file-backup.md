# File backup and restore

User approved file backup/restore after discussing manual Files/iCloud Drive export, preview before replacement, and protecting the pre-restore state. Implement in the current codex feature checkout; preserve real user data and internal Personal delivery. No new account/cloud synchronization.

- Settings offers a dedicated Backup & Restore page. Export creates a dated `.pentaphor` file through the system file exporter. Import uses the system file picker and scoped coordinated reads, validates before preview, and never changes data merely by selecting a file.
- Versioned JSON envelope contains app identity, format version 1, creation date, complete version-1 AppState as encoded payload, and SHA-256 checksum. Preserve quests (including archived/deleted), notes, target changes, rewards, completion snapshots/voids, preferences, timezone and weekly recap marker. Art binaries are bundled and excluded. No encryption/password claim. Reject >20 MiB, wrong app/version/checksum, invalid IDs/references/rewards/targets/periods/dates before replacement.
- Preview shows backup date, all quest definitions count, nonvoid completion count, totals and saved timezone; explicitly explain replacing current data. Confirmation only writes after validating and atomically storing a local pre-restore backup. Failure of safety backup or main save leaves current store unchanged. File cancellation leaves data unchanged.
- One latest pre-restore backup is retained in Application Support and exposed for preview/restoration via the same confirmation flow. It is on this device; external file export is the portable backup. Restore from it first retains the currently loaded state in that slot. No irreversible deletion or restore of the user's actual data during development.
- Successful restore recalculates totals from records, refreshes all dependent views and reminders, discards stale nickname drafts, and resets stale recap presentation/check state without interrupting the settings page. OS notification authorization is not part of backup. Restored preferences still gate notifications against live OS authorization.
- Pure codec/validator plus transactional store replacement and injected recovery repository. Native file-document adapter/view handles picker/exporter state separately from core.

## Interfaces
`BackupSnapshot: Identifiable, Sendable`: id String (checksum), createdAt Date, state AppState.
`BackupCodec.maximumFileSize: Int`; `make(state: AppState, at: Date) throws -> Data`; `read(_ data: Data) throws -> BackupSnapshot`.
`@MainActor BackupRecoveryRepository`: `load() throws -> Data?`, `save(_ data: Data) throws`.
`@MainActor FileBackupRecoveryRepository(directory: URL)` implements protocol, one atomic private file.
`BackupRestorer.restore(_ snapshot: BackupSnapshot, into store: QuestStore, recovery: any BackupRecoveryRepository, at: Date) throws`.
`QuestStore.replaceState(_ state: AppState) throws`: shared validation, save then publish only, plus observable replacement generation if needed by app.
`AppStateValidator.validate(_ state: AppState) throws`: extracted existing repository validation plus safe structural import checks; repository and import use same authority.

## Verification
TDD core roundtrip, tamper/version/size/invalid period/reference, legacy store compatibility, exact replacement/restart, safety/save failure and recovery reversal. App-hosted file-document and actual file reads. UI real export/import/cancel/preview/confirm/recovery and stable restored stats. Full default tests, signed build and exact Personal READY. Apple APIs: https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:) and https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app .
