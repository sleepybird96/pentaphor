# CHALLENGE 구매 및 검증

## 상품

- 앱: PENTAPHOR, `app.pentaphor.personal` / App Store Connect `6811887105`.
- 상품: `app.pentaphor.personal.challenge.lifetime`.
- 유형: 비소모성, 한 번 구매. 가족 공유는 활성화하지 않았다.
- 실제 생성된 상품 ID: `6817609340` (2026-09-30).
- 한국 5,900원 가격 포인트 존재 확인: `eyJzIjoiNjgxNzYwOTM0MCIsInQiOiJLT1IiLCJwIjoiMTAwNjQifQ`.
- 2026-09-30 관리자 UI에서 한국 기준 가격 5,900원, 한국어 표시 이름·설명, 심사 이미지·메모 저장 완료. 사용자 요청으로 전체 175개 지원 국가·지역 판매 가능 여부를 설정했다. API 상태 `READY_TO_SUBMIT` 확인. 공개 심사는 제출하지 않았다.

## 제품 정책

무료는 활성 퀘스트 8개, 각 파라미터 표시 99. CHALLENGE는 두 상한을 무제한으로 해제한다. 초과 성장도 원본 완료 기록에 보존한다. 보관·삭제·완료한 일회성은 활성 수에서 제외한다. 복원/업데이트/완료 취소로 8개를 초과해도 기존 항목은 사용 가능하고 생성·보관 해제만 제한한다.

구매 권한은 백업과 분리된다. 백업 파일을 가져와도 구매 권한은 이동하지 않는다. 같은 Apple 계정의 구매 복원은 설정 → CHALLENGE → 구매 복원에서 가능하다. 환불 시 원본 데이터는 삭제하지 않는다.

## 테스트 구분

- `Pentaphor` scheme: 일반 Core/native/UI 회귀용. 로컬 StoreKit 설정을 붙이지 않는다.
- `PentaphorStoreKitTests` scheme/target: 실제 StoreKit API와 SKTestSession 구매·복원·승인 대기·환불 통합 검증용.
- `Configuration/Challenge.storekit`: 로컬 시뮬레이션 전용. App Store Connect 가격 설정을 대신하지 않는다.
- `--ui-testing --ui-test-challenge --reset-test-store`: DEBUG 전용, 별도 UITestStore에 8개 퀘스트와 체력140을 생성하고 가짜 구매 경계로 시각 흐름을 검사한다. 실제 사용자 데이터와 실제 과금에 접근하지 않는다. 일반 UI 테스트도 네트워크 의존성 없는 DEBUG 구매 클라이언트를 사용한다.

## 관리자 화면에 저장된 한국어 메타데이터

- 표시 이름: CHALLENGE 영구 해금
- 설명: 퀘스트와 파라미터 상한을 한 번의 구매로 영구 해금합니다.
- 기준 국가: 대한민국, 5,900원. 저장 완료. 다른 지역 가격은 Apple 자동 환산을 사용한다.

## 저장된 심사 메모

CHALLENGE is a non-consumable, one-time unlock. Free users can maintain 8 active quests and see up to 99 points per parameter. Completing activities beyond 99 continues to preserve earned progress locally; purchasing reveals that stored progress and removes the active quest limit. No subscription, app login or app server is required. Settings → CHALLENGE → Restore Purchases restores the verified Apple purchase. All art, reminders, recap and file backup/restore remain available free. Refunds never delete activity history.

Review purchase access from Settings → CHALLENGE; reaching 99 points is not required to purchase. There are no production launch arguments or hidden switches that grant access.

## 검증 기록

배포 전 검증: Core 115개(기존 Swift Testing108 + XCTest7), 앱 단위47개, 배포 자동화19개 통과. 전체 UI/배포 결과는 아래에 별도로 기록한다. 초기 정책 Core4, 구매 서비스 Native7, 제한 액션 Native2, coordinator Native1, 해금 pure geometry Core2, 구매 UI2의 통과를 확인했다. 이 숫자는 전체 최종 회귀 결과가 아니다. StoreKit 통합 2개는 04:02 UTC 통과했다. 시뮬레이터 Debug에만 get-task-allow를 추가했으며 실제 iPhone/Release 서명은 유지한다. 승인·환불의 비동기 반영은 제한 시간 내 최종 권한으로 검증한다.


### 독립 리뷰와 시각 검증

직접 구현 후 독립 리뷰에서 복원 응답 경쟁, 알림과 구매 화면 충돌, 권한 확인 전 구매 노출을 발견해 수정했다. 재현 테스트의 실패를 확인한 뒤 앱 단위47개가 통과했고 리뷰어도 수정 내용을 확인했다. 해금 화면의 버튼 활성화와 실제로 누를 수 있는 복귀 화면까지 확인하도록 UI 테스트를 강화했다.

시뮬레이터 영상(실제 과금이 없는 DEBUG 구매 클라이언트):
- `~/Library/Developer/PentaphorDemos/challenge-20260930/challenge-99-to-140.mp4`
- `~/Library/Developer/PentaphorDemos/challenge-20260930/challenge-50-unchanged.mp4`
- 심사용 구매 화면 초안: 같은 폴더의 `challenge-purchase-review.png`.

실제 StoreKit API 통합 테스트와 위 시각 테스트는 별개다. 실제 TestFlight sandbox 상품 조회·구매는 아직 확인하지 않았다. 큰 글자/VoiceOver 실기기 수동 점검도 공개 출시 전에 남아 있다.

### TestFlight 납품

2026-09-30: **1.0(10), Personal READY** 확인, 배포 명령 종료0. 전체 회귀 Core115 + Native47 + UI23 + 자동화19, 별도 StoreKit2 =206개 통과. Release 서명 아카이브와 업로드 성공, 테스트용 코드/로컬 StoreKit 파일의 배포 제외 및60개 아트 패키징 확인. 테스트·아카이브·API 결과는 `~/Library/Developer/PentaphorDeliveries/20260930-041428-u0ucyzq7/`에 보존한다.

남은 작업: 비즈니스 화면에서 유료 앱 계약이 `신규` 상태임을 확인했다. Apple은 계약 전 계정 정보 업데이트 및 대한민국 규정 준수 확인, EU 판매를 위한 거래자 자격 확인을 요구한다. 계정 소유자가 해당 정보를 입력하고 유료 앱 계약·세금·은행 설정을 완료해야 한다. 실제 TestFlight sandbox 상품 조회·구매/복원도 아직 확인하지 않았다. 공개 심사 제출은 하지 않았다. 일반 개발 실행에는 `Pentaphor` 스킴을 선택한다. CLI 배포는 정상 `Pentaphor` 스킴을 사용했다.

### 저장소 이전

2026-09-30 사용자 요청에 따라 기존 커밋 이력과 디자인·아트 원본을 `~/dev/pentaphor`에 보존하고 `https://github.com/sleepybird96/pentaphor.git`의 `main`에 push했다. 앞으로 이 경로에서 개발한다. 배포 키는 기존 `~/.config/deploy-credentials/`에 유지한다. 새 경로에서 Core115개와 배포 자동화19개 테스트 통과. 앱 코드 변경이 없는 저장소 이전·문서 작업이므로 새 바이너리는 배포하지 않았다.
