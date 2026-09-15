# File Backup Implementation Plan

> Execute continuously using superpowers:subagent-driven-development with disjoint file ownership and root-only simulator/deployment.

**Goal:** Portable file backup, validated preview/replacement, and recoverable restore.
**Architecture:** Pure codec/shared validator, transactional store replacement and recovery file repository, native document adapters and settings flow.
**Tech Stack:** Swift 6, SwiftUI iOS17+, SwiftData, CryptoKit, XCTest/Swift Testing.
**Spec:** docs/superpowers/specs/2026-09-15-file-backup.md

## Global Constraints
AppState version1; bundle app.pentaphor.personal; team NX53XT8XMU; Personal internal-only; 20 MiB files; preserve actual user data; no credentials in repo.

## Task 1: Core codec and safe restoration (agent, core only)
- [ ] Add BackupArchive.swift, AppStateValidator.swift, BackupRecovery.swift, BackupTests.swift; modify StateRepository.swift and QuestStore.swift only. Exact interfaces in spec.
- [ ] RED tests: `let bytes = try BackupCodec.make(state: engine.state, at: date); #expect(try BackupCodec.read(bytes).state == engine.state)` fails using stub. Corrupt one payload byte; wrong version/app/checksum, oversize and invalid reference/period reject. Real in-memory/disk repositories verify restore survives restart and pre-restore recovery is exact. Inject throwing save boundaries to assert current state unchanged.
- [ ] Implement codec using validated payload+SHA256 and versioned envelope, shared validator, recovery save before `store.replaceState(snapshot.state)`; GREEN focused and full core. Root owns all simulator work.

## Task 2: Native adapter and settings flow (root)
- [ ] Add BackupDocument.swift/FileDocument and BackupSettingsView.swift, scoped coordinated import. Core API exact spec. Declare app.pentaphor.backup UTType/.pentaphor in Info.plist.
- [ ] Native RED file document read/write and invalid input; UI RED missing settings.backup. Real system export/import flow on isolated test store must verify export file, preview cancellation unchanged, restore replaces and local recovery reverses it.
- [ ] Add Settings navigation; explain local recovery/export destination; restore success updates nickname draft and recap checks, existing state task resyncs reminders. UI IDs backup.export/import/restore/recovery/preview and test fixtures restricted to --ui-testing.
- [ ] GREEN native/UI, screenshots and cancellation checks.

## Task 3: Review and delivery (root)
- [ ] Independent review core/app + target-fix integration. Resolve actual findings using regression tests.
- [ ] Full `python3 scripts/testflight.py deploy`, verify exact Personal READY, update guides/spec evidence, commit only owned files.
