# PENTAPHOR project instructions

## Default delivery workflow

The user explicitly requested on 2026-09-15 that new app versions always be uploaded to TestFlight after changes.

- After completing changes to the app, run the relevant tests and build checks, then archive and upload a new build to the existing TestFlight internal group `Personal`.
- This is standing authorization for internal TestFlight distribution. Do not ask for upload permission again unless the scope changes.
- Follow `docs/testflight-internal.md` and `Configuration/TestFlightExport.plist`. Preserve the bundle ID, signing team, existing user data, and internal-only distribution.
- Use a new build number and unique archive path. Verify Apple processing and availability in `Personal`; distinguish successful upload from a build that is ready to install.
- If authentication, signing, or Apple processing blocks delivery, report the actual state and the specific required action. Never claim a build is available without checking.
- Documentation-only changes do not require another binary upload. Do not submit to the public App Store or external testers without user authorization.
