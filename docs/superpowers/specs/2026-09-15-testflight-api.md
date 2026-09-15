# TestFlight API delivery

Approved flow: tests → signed Release archive → API-key authenticated upload → Apple processing wait → Personal internal availability verification. Extend the existing local Xcode delivery; no CI hosting or scheduling required.

Credentials: user-issued team API key, key ID, issuer ID. Store config and private key outside repository under ~/.config/pentaphor with directory 0700 and files 0600. Never log private keys or JWTs. Read-only App Store Connect REST calls use short-lived ES256 JWTs. Xcode receives key path/IDs, never key content. Initial Apple login/key issuance is the only user setup; do not generate credentials or accept legal terms without applicable confirmation.

App fixed to 6811887105 / app.pentaphor.personal, team NX53XT8XMU. Find exactly one Personal internal group and require automatic distribution. Allocate next numeric build number from the current marketing version's server builds and local build setting. Lock concurrent local deployments. Keep unique local artifacts. Override only archive build number, set exporter automatic renumbering false so verification checks the exact uploaded binary.

Deployment must stop before archive/upload on failed tests. API authentication/permission errors fail clearly, transient rate/server/network failures retry boundedly. Wait at most 30 minutes, refreshing JWT per request; a timeout reports pending rather than success. Processing FAILED/INVALID, expired builds, unexpected audience, or missing export compliance fail without falsely claiming readiness. Success requires exact app/version/build/iOS, VALID, INTERNAL_ONLY, internal state IN_BETA_TESTING and membership in Personal. Read-only status can resume after timeout without uploading another build.

Tests run offline with ephemeral signing keys, real JWT signature verification, request-level fake HTTP responses and fake command runner; assert failure gates, matching/version filters, pending→ready behavior, errors, pagination safety, locks and upload arguments. One live API status query and API-authenticated deployment are required once the user supplies credentials. Existing app functionality is unchanged by this tooling.
