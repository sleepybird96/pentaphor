# CHALLENGE Lifetime Unlock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 무료 8개·99 상한과 5,900원 CHALLENGE 영구 해제, 보존된 성장의 해금 연출을 구현하고 TestFlight Personal에서 검증한다.

**Architecture:** 원본 QuestEngine과 백업 형식을 보존하고 순수 표시·이용 정책을 추가한다. StoreKit 2 검증을 담당하는 PurchaseService와 구매 화면/해금 표시 coordinator를 분리한다. 화면은 일관된 표시 모델을 사용하며 기록·알림·끈기 계산은 원본 데이터를 사용한다.

**Tech Stack:** 기존 Swift 6 / iOS 17+ / SwiftUI / Observation / PentaphorCore, StoreKit 2, StoreKitTest, XCTest, XcodeGen. 외부 결제 SDK·서버를 추가하지 않는다.

**Spec:** `docs/superpowers/specs/2026-09-30-challenge-unlock-design.md` (사용자 승인 완료).

## Global Constraints

- 무료 진행 중 퀘스트 8개·각 파라미터 99, CHALLENGE 해금 후 두 상한 모두 무제한.
- 한국 판매가 5,900원 한 번 구매. 비소모성 1개, 제안 ID `app.pentaphor.personal.challenge.lifetime`. 실제 상품 ID 중복 확인 전 외부 생성하지 않는다.
- ∞는 상한 표기에 사용하고 실제 파라미터는 숫자다. 구매 가격은 StoreKit의 현지화 문자열을 사용한다.
- 원본 누적 기록·보상·끈기·백업 파일은 상한으로 잘라내지 않는다. 해금은 보상 지급이 아니다.
- 아트·알림·주간 정산·메모·백업·복원은 무료에도 모두 제공한다.
- 앱 계정·서버·월 구독·모드 토글·Android 구현을 추가하지 않는다.
- 구매 권한은 AppState 및 사용자 백업에 저장하지 않는다. 배포 앱에는 테스트 해금 우회 경로를 넣지 않는다.
- 번들 ID `app.pentaphor.personal`, 팀 `NX53XT8XMU`, 기존 사용자 데이터와 iCloud 서명을 유지한다.
- 완료 후 `python3 scripts/testflight.py deploy`; 처리 지연은 `status --version VERSION --build BUILD --wait`로 이어서 확인한다. Personal 설치 가능 상태와 업로드 성공을 구분한다.
- 이 작업에서 공개 심사 제출·자동 출시는 하지 않는다. 문서 작성 단계에는 상품 생성·결제·배포를 실행하지 않는다.

## Review Focus

1. 구매 승인 대기 중 앱 종료 후 승인: 업데이트 수신으로 정상 해금하고 거래를 중복 처리하지 않는다(Task 2/5).
2. 복원 파일로 상한 초과 또는 편집 도중 권한 변경: 데이터는 보존하되 저장 시 최신 권한·개수를 재검사한다(Task 3).
3. 구매 이후 거래 완료 호출 전에 종료: 재수신해도 권한은 유지되고 연출·햅틱·보상이 중복되지 않는다(Task 2/5).
4. 오프라인·상품 조회 실패: 이미 검증된 권한을 임의로 박탈하거나 잘못된 가격으로 결제시키지 않는다(Task 2/4).
5. 해금 연출 중 데이터 복원 또는 정산 요청: 다른 상태의 숫자와 섞이지 않고 한 화면씩 표시한다(Task 5).

## 공통 실행·검증 규칙

실행 시 using-git-worktrees 절차로 현재 checkout 또는 적합한 기존 worktree를 확인한다. 무관한 untracked 에셋은 건드리지 않는다. 테스트를 먼저 작성하고 실제 실패를 확인한 뒤 최소 구현·green·리팩터링·해당 파일만 커밋한다. 매 단계 전체 UI 테스트를 반복하지 않고 변경에 맞는 테스트만 실행한 뒤 마지막 단계에서 전체 회귀를 실행한다.

경로 약칭:

- **C** = `Packages/PentaphorCore/Sources/PentaphorCore/`
- **CT** = `Packages/PentaphorCore/Tests/PentaphorCoreTests/`
- **A** = `Pentaphor/App/`
- **V** = `Pentaphor/Views/`
- **NT** = `PentaphorTests/`
- **UT** = `PentaphorUITests/`

Core 테스트: `swift test --package-path Packages/PentaphorCore --filter TEST_CLASS`.
Native/UI 테스트: `xcodebuild test -project Pentaphor.xcodeproj -scheme Pentaphor -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -only-testing:TARGET/TEST_CLASS`. 실행 시 `xcrun simctl list devices available`에서 테스트 전용 iPhone 시뮬레이터 UUID를 확인하고 치환한다. 한 번에 하나의 시뮬레이터 테스트 작업만 실행한다. 실제 사용자 폰 데이터는 테스트로 바꾸지 않는다.

## Task 1: 순수 상한 정책과 표시 모델

**Files:** Create `C/ChallengePolicy.swift`, `CT/ChallengePolicyTests.swift`. Read `C/Domain.swift`, `C/QuestEngine.swift`, `C/WeeklyRecap.swift`, `C/RadarGrowth.swift`.

**Interfaces:** `ChallengeAccess: Equatable, Sendable { case free, unlocked }`. `ChallengePolicy.displayed(_ raw: StatPoints, access: ChallengeAccess) -> StatPoints`, `.canAddActiveQuest(count: Int, access: ChallengeAccess) -> Bool`. `ChallengeGrowthPresentation(before: StatPoints, after: StatPoints, access: ChallengeAccess)` exposes `displayBefore`, `displayAfter`, `displayDelta`, `hasHiddenGrowth`; raw inputs are never mutated.

- [ ] Write `capsEachAxisWithoutChangingRaw`: `XCTAssertEqual(displayed.stamina, 99)` for raw stamina101; assert raw stamina remains101, other axes unchanged, unlocked displays101. Assert displayed.total is sum of capped values, not capped raw.total.
- [ ] Write `quotaBoundary`: free count7=true, count8/9=false, unlocked count100=true. `growthCrossingCap`: raw98→100 produces display98→99 and delta1; raw99→101 delta0 and hidden=true; raw101→98 display99→98; perseverance follows same cap.
- [ ] Run `swift test --package-path Packages/PentaphorCore --filter ChallengePolicyTests` to red.
- [ ] Implement immutable policy and presentation type. Leave QuestEngine.totals, completion rewards, period/streak calculations and RadarGrowth formula unchanged.
- [ ] Repeat test to PASS; commit only Task 1 files.

## Task 2: 검증 가능한 StoreKit 구매 서비스

**Files:** Create `A/ChallengePurchaseService.swift`, `A/StoreKitChallengeClient.swift`, `A/ChallengeTransactionLedger.swift`, `NT/ChallengePurchaseServiceTests.swift`, `NT/ChallengeStoreKitTests.swift`, `Configuration/Challenge.storekit`; Modify `project.yml` and generated Xcode project to add a separate `PentaphorStoreKitTests` scheme with local StoreKit configuration.

**Interfaces:** `ChallengeEntitlementState { checking, resolved(ChallengeAccess), unavailable }`; unavailable is unresolved, not confirmed free. `ChallengeProduct(id:String,displayPrice:String)`, `ChallengePurchaseOutcome { verified(ChallengeTransaction), pending, cancelled }`, `ChallengeTransaction(id:UInt64,productID:String,isRevoked:Bool)` only produced after verification by the real adapter. `ChallengeStoreClient` exposes async throwing `loadProduct()`, `currentEntitlement() -> ChallengeAccess`, `purchase() -> ChallengePurchaseOutcome`, `sync()`, `finish(transactionID:)`, and `updates: AsyncStream<ChallengeTransaction>`.

`@MainActor @Observable ChallengePurchaseService` exposes `entitlement`, `product`, `purchaseState`, `lastError`; methods `start()`, `refresh() async`, `purchase() async`, `restore() async`. It emits `ChallengeUnlockEvent(transactionID:UInt64)` for newly delivered purchases, not ordinary startup entitlement discovery or restore. Ledger stores handled transaction IDs outside AppState; IDs confer no entitlement.

- [ ] Fake client tests: verified matching ID unlocks; wrong product/unverified never unlocks; cancelled returns idle; pending keeps access unchanged; repeated taps call client once. Startup failure resolves unavailable and shows retry; transient refresh failure retains previously verified access. Confirmed revocation resolves free.
- [ ] Test `pendingApprovalAfterRestart`, `duplicateDeliveryFinishesIdempotently`, `restoreDoesNotEmitCelebration`, `finishFailureRetriesWithoutDuplicateUnlock`: `XCTAssertEqual(unlockEvents.count, 1)` for repeated delivery and `XCTAssertEqual(engine.state, originalState)` for every purchase outcome.
- [ ] Run Native `ChallengePurchaseServiceTests` to red using the command template above.
- [ ] Implement adapter using verified StoreKit 2 transactions, start updates listener before entitlement scan, filter product/revocation, cancel task at service teardown, finish handled transactions. Purchase restore calls AppStore.sync only from explicit user action. Keep checking/unknown distinct from free; never trust UserDefaults boolean as entitlement. Store transaction presentation marker before triggering animation; missed celebration after crash is preferable to duplicate celebrations.
- [ ] Add SKTestSession tests for non-consumable purchase, restore, approval, refund and restart. Local store has the intended product/price for simulation; document that this is not an App Store price confirmation. Run Native and local StoreKit tests to PASS; verify normal TestFlight scheme has no local store override. Commit Task 2 files.

## Task 3: 일관된 제한 적용과 데이터 보존

**Files:** Create `A/ChallengeQuestActions.swift`, `A/ChallengeNoticeStore.swift`, `NT/ChallengeQuestActionsTests.swift`, `CT/ChallengeBackupTests.swift`; Modify `V/QuestEditor.swift`, `V/QuestHome.swift`, `V/JournalViews.swift`, `V/AchievementView.swift`, `V/WeeklyRecapView.swift`, `V/BackupSettingsView.swift`, `A/PentaphorApp.swift`.

**Interfaces:** `@MainActor ChallengeQuestActions` owns QuestStore and purchase service. `create(_ mutation:(inout QuestEngine)throws->Void) throws` and `unarchive(questID:UUID) throws` validate resolved access and current active count immediately before store.transact. `ChallengeActionError { checkingAccess, accessUnavailable, activeQuestLimit }`. Existing edit/archive/delete/complete/undo/restore remain unrestricted. `ChallengeNoticeStore` records per-stat first-cap notices and one migration notice in device-local presentation state, never purchasing rights.

- [ ] Test free 7→8 success, 8→9 rejection without repository write, premium success, unarchive capacity check, updating existing quest while over capacity. Imported 12 active quests and raw120 remain intact and all existing quests usable. Undo of completed once may exceed8; new creation then rejects. Permission changed while editor open is rechecked on save.
- [ ] Backup round-trip asserts `XCTAssertEqual(restored.totals.stamina,120)` and no entitlement field; free display99/unlocked120 from same backup. Cap crossing notice only once per stat, no automatic paywall; migration notice for existing excess and no data rewrite.
- [ ] Run Native `ChallengeQuestActionsTests` and Core `ChallengeBackupTests` to red.
- [ ] Implement app action boundary and inject shared purchase service. Apply Task 1 display models to all current stat totals/radars including history and recap. Keep actual reward cards unchanged; clarify 98+2 → displayed99 vs reward+2. Backup preview labels raw totals ‘누적 성장(상한 이후 포함)’. During initial entitlement checking/unavailable show a brief status/retry instead of displaying a false free limit or uncapped totals.
- [ ] Run tests to PASS; audit all `engine.totals`/ParameterRadar call sites for intended raw vs display behavior. Verify prior completion, current-target-edit and backup tests stay green; commit Task 3 files.

## Task 4: 해금 화면과 구매·복원 동선

**Files:** Create `V/ChallengePaywall.swift`, `UT/ChallengePurchaseFlowTests.swift`, `A/ChallengeUITestScenario.swift`; Modify `V/SettingsView.swift`, `V/QuestHome.swift`, `V/QuestEditor.swift`, `V/JournalViews.swift`, `V/BrandCopy.swift`.

**Interfaces:** `ChallengePaywall(service:ChallengePurchaseService,onClose:()->Void)` displays free8/99 vs ∞/∞, local product price, purchase/restore actions and state/error. DEBUG-only injected scenario enables deterministic tests; release builds cannot activate it through launch arguments or defaults.

- [ ] Write UI tests: settings opens paywall; cap hit uses inline CTA; ninth quest creation opens paywall; cancel preserves draft fields; verified success resumes original flow; no repeated purchase button while processing; pending is dismissible. Product loading failure shows retry and restore without made-up price. Restore success without entitlement says no purchase found; failure says retry, not ‘무료로 변경’.
- [ ] Assert exact copy `CHALLENGE`, `99 너머의 성장을 해금해.`, `한 번 구매하면, 계속 사용할 수 있어.` and accessibility label ‘무제한’. App information/data explanations use 존댓말; purchase experience uses existing casual tone.
- [ ] Run `PentaphorUITests/ChallengePurchaseFlowTests` to red.
- [ ] Implement existing cream/ink/teal design, dismiss/restore/settings badge and real localized price. Gate entry and save without destroying the editor. Add functioning privacy/terms destinations using existing ones if present; if no hosted privacy policy exists, prepare its content for launch work and explicitly record the unresolved URL rather than shipping a dummy link.
- [ ] Run UI tests to PASS and inspect large text/VoiceOver/contrast. Confirm receipt testing controls compile only under DEBUG; commit Task 4 files.

## Task 5: 99 → ∞ 해금 연출과 화면 조정

**Files:** Create `C/ChallengeUnlockPresentation.swift`, `CT/ChallengeUnlockPresentationTests.swift`, `A/ChallengeUnlockCoordinator.swift`, `NT/ChallengeUnlockCoordinatorTests.swift`, `V/ChallengeUnlockView.swift`; Modify `V/ParameterRadar.swift`, `V/QuestHome.swift`, `A/WeeklyRecapCoordinator.swift` only as needed for shared busy state.

**Interfaces:** `ChallengeUnlockPresentation(raw:StatPoints)` supplies capped start, actual finish, `radii(progress:Double,simplified:Bool) -> [Double]` and `numbers(progress:Double) -> StatPoints`. `ChallengeUnlockCoordinator.enqueue(event:ChallengeUnlockEvent)`, `presentIfPossible(store:QuestStore,isBusy:Bool)`, `finish()` with captured replacementGeneration; raw totals captured when presenting, not when purchase started. Purchase service remains authority whether the animation runs or not.

- [ ] Core tests: raw140 starts99 and ends140; raw50 starts/ends50 with decorative pulse only; changing only courage never changes other final radii; progress clamps; all radii finite/in bounds; simplified ends at actual values. Assert source AppState unchanged.
- [ ] Native tests: repeated transaction ID → one presentation and at most one haptic; pending/editor/achievement/recap defer; restoring data invalidates an already presenting snapshot and safely dismisses it without reverting entitlement; closing unlock allows queued recap. Crash/relaunch rechecks access without replaying already handled event.
- [ ] Run both new test classes to red.
- [ ] Implement 1.2s sequence: 0–0.2 cap emphasis; 0.2–0.4 cap labels→∞; 0.4–0.95 independent axis burst/count-up; 0.95–1.2 settle with `CHALLENGE UNLOCKED` / `성장의 한계를 해금했어.`. Overshoot is decorative and final geometry follows existing RadarGrowth. Small/no raw growth still gets a pulse without fabricated numbers. Reduced motion/simplified effects use fade/final values; user haptics setting respected. Do not alter launch loading animation behavior.
- [ ] Run tests to PASS and UI test purchase→unlock→return; verify cancellation of animation tasks on dismissal. Record preview for raw99,140,50 and one-axis change; commit Task 5 files.

## Task 6: 실제 상품 설정과 출시 인계 자료

**Files:** Create `docs/challenge-storekit.md`, `docs/app-store-launch-checklist.md`; Modify production product ID configuration only if reusing an existing actual product ID.

**Interfaces:** App Store Connect non-consumable matches app product ID; Korean title CHALLENGE 영구 해금; description explains both unlimited limits and one-time purchase. No additional app accounts/backend keys.

- [ ] Inspect existing app/IAP IDs and agreement status using current authenticated tooling. Check Korean 5,900원 price point and record exact IDs without secrets. If API permissions are insufficient, use available authenticated UI; if account-owner agreements/tax/banking are missing, report precisely and continue local tests/docs rather than inventing values.
- [ ] Create or reuse the non-consumable under approved pricing scope and fill review metadata. Do not enable irreversible optional Family Sharing or expand storefront availability on inference; inherit applicable app availability where supported. Product configuration is not a public release.
- [ ] Prepare purchase-screen screenshot, review instructions, restoration path, free caps and hidden-growth explanation. Record real store product fetch and sandbox verification separately from StoreKit local simulation. Missing product approval/configuration must remain visible as a blocker, not patched with a mock in release.
- [ ] Create release checklist for privacy/support URL, actual data collection declarations, age rating, screenshots/copy, territories, Paid Apps Agreement/tax/bank state, IAP+app combined first review and chosen release timing. Record unresolved human inputs without claiming launch-ready.
- [ ] Verify every documented identifier/price against inspected metadata and run relevant product-loading tests if config changed. Commit docs/config only. Do not submit public review in this task.

## Task 7: 전체 회귀·영상·TestFlight 납품

**Files:** Update `docs/challenge-storekit.md` with verification evidence; add dedicated demo tooling only if existing simulator scenario/recording commands are insufficient.

- [ ] Run `swift test --package-path Packages/PentaphorCore`; run complete PentaphorTests/PentaphorUITests via normal scheme plus separate StoreKit test scheme. All required tests must pass. Run `python3 -m unittest discover -s scripts/tests` and applicable asset/build checks required by existing delivery docs.
- [ ] Review actual diff for raw-data mutations, entitlement leakage into backups, free-cap bypass paths, restore/refund behavior, unfinished URLs and DEBUG-only controls. Use execution method's independent review; fix findings and re-run affected tests. Do not weaken tests to get green.
- [ ] Record simulator video showing free99 → purchase simulation → ∞ burst → actual saved growth, plus below99 purchase with no numerical gain. Store MP4 under `~/Library/Developer/PentaphorDemos/` and label local StoreKit simulation. Never modify user phone data for demo.
- [ ] Run `python3 scripts/testflight.py deploy`; preserve signing/export config and choose new build number/unique archive. If processing times out, resume with `python3 scripts/testflight.py status --version VERSION --build BUILD --wait`.
- [ ] Verify processing valid and build available in Personal. Exercise real TestFlight sandbox product fetch/purchase/restore when an authenticated test device is available; otherwise explicitly report that step unverified even if local StoreKit tests pass. Do not charge a production purchase for testing.
- [ ] Report build version, installation readiness, tests, video link, outstanding App Store account/metadata actions. Distinguish internal TestFlight delivery from public release and real purchase availability. Commit final evidence docs without binaries/credentials.

## Self-review and execution handoff

Spec coverage: caps/data preservation Task1/3; verified purchases and restore Task2; copy and discovery Task4; visual burst and collision handling Task5; product metadata and public-launch boundary Task6; TDD/regressions/video/internal delivery Task7. All five Review Focus cases have owning tests. No original record or backup migration is necessary for the cap feature.

Plan approval and execution method selection remain pending. Recommendation: Native execution in this session, then independent final review. The seven tasks share entitlement and presentation state, so one implementer can keep interface decisions consistent; StoreKit and data preservation still receive focused automated tests and final independent review. Alternative: Subagent-driven with separate implementer/reviewer per task for more frequent independent review at higher context cost.
