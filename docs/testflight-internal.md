# TestFlight 내부 배포

- 앱: PENTAPHOR
- App Store Connect 앱 ID: `6811887105`
- 번들 ID: `app.pentaphor.personal`
- 개발자 팀: `NX53XT8XMU` (JiSang Park)
- 기본 언어: 한국어
- SKU: `pentaphor-ios`
- 내부 그룹: `Personal` (자동 배포 활성화)
- [TestFlight 관리 화면](https://appstoreconnect.apple.com/teams/3e6d8ea1-9f82-47b0-9337-3e53a19f49fe/apps/6811887105/testflight)

## 첫 배포 확인

2026-09-14에 **1.0 (1)** 업로드와 Apple 처리가 완료됐다. `Personal` 그룹의 빌드 상태는 **내부 · 테스트 중**, 계정 소유자는 **초대됨**으로 확인했다. 아이폰에서 초대 메일을 열고 TestFlight로 설치한다.

## 기본 배포 정책

2026-09-15 사용자 요청: 앞으로 앱 변경을 완료하면 관련 테스트·빌드 검증 후 새 버전을 TestFlight 내부 그룹 `Personal`까지 배포한다. 이는 지속적인 내부 배포 승인으로, 매번 업로드 여부를 다시 묻지 않는다. 업로드 성공과 Apple 처리 완료를 구분해 확인하고, 설치 가능한 빌드 번호를 보고한다. 문서만 수정한 경우는 새 바이너리 업로드가 필요하지 않다.

## API 키 기반 기본 명령

처음 한 번 App Store Connect의 **사용자 및 액세스 → 통합 → App Store Connect API → 팀 키**에서 키를 발급한다. 현재 자동화는 `PENTAPHOR TestFlight`라는 **제품 개발** 권한의 팀 키를 사용한다. 팀 키는 계정의 모든 앱에 해당 권한이 적용된다. 스크립트는 PENTAPHOR 앱 ID와 내부 그룹 `Personal`을 고정 검증한다.

필요 환경: Xcode, Python 3.11+, `scripts/requirements-testflight.txt`의 cryptography. 현재 Mac에는 해당 버전이 설치되어 있다. 새 환경에서는 프로젝트 밖의 가상환경에 의존성을 설치한다.

키 파일을 한 번 연결한다. 아래 값은 다운로드한 키의 경로와 Apple 화면에 표시된 ID로 교체한다.

```sh
python3 scripts/testflight.py configure \
  --key-file /absolute/path/AuthKey_KEY_ID.p8 \
  --key-id KEY_ID \
  --issuer-id ISSUER_ID
```

키와 설정은 `~/.config/pentaphor/`에 복사하며 디렉터리 0700, 파일 0600 권한으로 제한한다. 프로젝트 밖에 저장하고, 키 원문과 JWT는 로그에 출력하지 않는다. 기존 설정은 덮어쓰지 않는다. `.p8` 파일은 Git에서도 제외한다.

이후 앱 변경을 배포할 때 실행한다.

```sh
python3 scripts/testflight.py deploy
```

스크립트는 다음을 차례대로 실행한다.

1. 키 인증, 앱 ID·서명 팀, `Personal` 내부 그룹 및 자동 배포 설정 확인
2. 현재 마케팅 버전의 서버 빌드 번호와 로컬 설정에서 다음 번호 선택
3. 자동화 테스트, Release 코어 테스트, 전체 iPhone UI 테스트
4. 선택한 번호로 Release 아카이브와 API 인증 업로드
5. 최대 30분간 Apple 처리와 `Personal` 배포 상태 확인

UI 테스트는 전용 테스트 저장소를 사용한다. 시뮬레이터는 기본 iPhone 17 Pro를 사용하며 필요하면 `deploy --simulator DEVICE_UUID`로 지정한다. 로컬 동시 배포는 잠금으로 차단한다. 모든 아카이브·업로드·테스트 로그는 `~/Library/Developer/PentaphorDeliveries/` 아래 실행마다 새 디렉터리에 남긴다. `delivery.json`에 정확한 버전과 빌드 번호가 기록된다. exporter의 자동 번호 변경은 이 실행에서 끄고, 확인 대상과 업로드 번호를 일치시킨다.

API 응답의 빌드가 정확한 앱·iOS·버전·번호와 일치하고, `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING`, `Personal` 그룹 포함을 모두 만족해야 `READY`라고 보고한다. 인증/권한 오류, 거절, 만료, 수출 규정 추가 확인은 성공으로 처리하지 않는다. 공개 App Store 제출이나 외부 테스터 추가는 하지 않는다.

기존 업로드 확인이나 처리 시간 초과 후 재확인은 바이너리를 다시 올리지 않고 실행한다.

```sh
python3 scripts/testflight.py status --version 1.0 --build 2 --wait
```

`status` 종료 코드 0은 준비 완료, 2는 대기 중, 1은 설정·인증·처리 오류 또는 대기 시간 초과다. Apple 점검, 인증서 만료, 약관 갱신처럼 사람이 처리해야 하는 일은 별도 안내한다. 새 키 생성이나 폐기 없이 웹 로그인 쿠키와 독립적으로 인증한다.

## 수동 복구

API 자동화에 문제가 생겨도 기존 `Configuration/TestFlightExport.plist`와 `xcodebuild archive` / `xcodebuild -exportArchive` 흐름은 유지된다. 업로드 결과가 불확실할 때는 먼저 `delivery.json`의 번호를 `status`로 조회해 중복 업로드를 피한다. 아카이브 경로를 재사용하거나 기존 앱을 지우지 않는다.

공식 근거: [API 키](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api), [Apple OpenAPI 명세](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip), [내부 그룹 자동 배포](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers).

## 배포 설정

앱 타깃의 `TARGETED_DEVICE_FAMILY`를 `1`로 명시한다. XcodeGen은 프로젝트 공통 설정만 지정하면 앱 타깃에 `1,2`를 생성할 수 있어, 아이폰 세로 전용 화면이 아이패드 멀티태스킹 검증에서 거절된다.

`ITSAppUsesNonExemptEncryption = false`는 현재 코드와 의존성이 별도 암호화 기능을 구현하지 않는다는 확인에 기반한다. 암호화 기능이나 SDK를 추가할 때 다시 확인한다. [Apple의 암호화 항목 안내](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)

TestFlight의 같은 번들 ID 앱으로 업데이트하며, 기존 앱을 먼저 삭제하지 않는다. 사용자 기록은 기기에 저장되며 동기화/백업 기능은 아직 없다.

## 최근 업로드

2026-09-15 **1.0 (2)**: 1회성 퀘스트와 통합 목록. 77개 테스트 통과 후 Release 아카이브 및 추가 Release 코어 테스트 66개 통과. Apple 업로드는 03:10:07 UTC에 성공했다. 재로그인 후 `Personal` 내부 그룹에서 **1.0 (2) · 내부 · 테스트 중** 상태를 확인했다. 현재 설치 가능한 빌드다.

## API 연결 진행 상태

자동화 코드와 19개 오프라인 테스트, 실제 Xcode 설정 JSON 조회 검증은 완료됐다. API 이용 신청과 `PENTAPHOR TestFlight` 제품 개발 키 생성도 완료됐다. 다만 첫 다운로드가 중단되어 로컬 `.p8` 파일을 아직 확보하지 못했다. `configure`와 실제 API 조회/배포 검증은 키 다운로드 복구 또는 새 키 발급 후 이어서 진행한다. 이 상태를 API 자동화 연결 완료로 보고하지 않는다.
