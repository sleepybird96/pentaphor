# iCloud Drive-only manual backup

The user selected iCloud Drive-only backup after reporting that the default Files export location could be deleted with the app. New manual saves go directly to the app's dedicated iCloud Documents container, displayed as PENTAPHOR in iCloud Drive. No automatic backup on quest mutations and no live app-state synchronization. Existing `.pentaphor` imports and transactional preview/restore remain compatible.

- Xcode registered `iCloud.app.pentaphor.personal` for the existing app ID and iCloud Documents only. Preserve bundle/team, existing state and internal Personal distribution. Declare entitlements in XcodeGen and publish the Documents scope in Info.plist.
- Resolve the real container on a background task for each operation. If unavailable, fail with actionable iCloud guidance; never fall back to local Documents. Save each validated archive with a unique dated filename using coordinated atomic writes. Preserve earlier backups.
- Show the destination and each new backup's filename. Writing a file only means upload is pending; show uploaded only when Foundation reports a ubiquitous item with uploaded=true. Surface upload errors and allow refresh; do not promise deletion safety before upload completes. Recheck the active container so account changes cannot leave a stale success indication.
- Import opens Files at the current iCloud Documents directory when available, with ordinary file selection retained for previous-version/manual backups. Selection still only previews; confirmation safely replaces state.
- Tests: real disk writer and codec roundtrip, unique historical files, unavailable/no local fallback, blocked directory preservation, unconfirmed local file never reported uploaded, changed account rejects old URL. UI save has no export location picker; unavailable mode does not fall back; actual Files import/preview/cancel/recovery/relaunch remains tested. Simulator test-only cloud directory substitutes only the unavailable platform container; no claim of live iCloud upload from fixture results.
- Verify all tests and signing entitlements, then default TestFlight deploy and exact Personal READY. Real-device iCloud transport is a separate acceptance check if no logged-in test device is available.

Primary sources: [Configuring iCloud](https://developer.apple.com/documentation/xcode/configuring-icloud-services), [iCloud document design](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html), [upload metadata](https://developer.apple.com/documentation/foundation/urlresourcevalues/ubiquitousitemisuploaded).

## Delivery evidence
180 tests passed; signed archive entitlements verified; 1.0 (9) uploaded and exact Personal READY confirmed. Implementation `90d3a14`; detailed RED/GREEN and live delivery evidence in docs/development-log.md. Live iCloud transfer on the user's iPhone is not simulated by the test fixture.
