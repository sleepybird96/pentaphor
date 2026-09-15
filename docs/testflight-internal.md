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

처음 한 번 App Store Connect의 **사용자 및 액세스 → 통합 → App Store Connect API → 팀 키**에서 키를 발급한다. 자동화에는 **제품 개발** 권한의 팀 키를 연결한다. 팀 키는 계정의 모든 앱에 해당 권한이 적용된다. 스크립트는 PENTAPHOR 앱 ID와 내부 그룹 `Personal`을 고정 검증한다.

필요 환경: Xcode, 유효한 로컬 Apple Distribution 인증서와 해당 인증서를 포함하는 App Store 배포 프로파일, Python 3.11+, `scripts/requirements-testflight.txt`의 cryptography. 현재 Mac에는 해당 버전이 설치되어 있다. 새 환경에서는 프로젝트 밖의 가상환경에 의존성을 설치한다.

키 파일을 한 번 연결한다. 아래 값은 다운로드한 키의 경로와 Apple 화면에 표시된 ID로 교체한다.

```sh
python3 scripts/testflight.py configure \
  --key-file /absolute/path/AuthKey_KEY_ID.p8 \
  --key-id KEY_ID \
  --issuer-id ISSUER_ID
```

배포 자격 증명의 공용 보관 루트는 `~/.config/deploy-credentials/`다. Apple 키와 설정은 서비스·팀별 경로 `apple/NX53XT8XMU/`에 보관한다. 같은 개발자 팀의 다른 앱에서도 이 위치를 재사용하며 프로젝트별로 키를 복제하지 않는다.

현재 기본 설정은 `~/.config/deploy-credentials/apple/NX53XT8XMU/app-store-connect.json`, 개인키는 같은 폴더의 `AuthKey.p8`이다. 디렉터리 0700, 파일 0600 권한으로 제한하며 키 원문과 JWT는 로그에 출력하지 않는다. `configure`는 지정한 원본을 이 위치에 복사하고 기존 설정을 덮어쓰지 않는다. 처음 연결하거나 교체할 때는 새 경로의 실제 API 인증을 검증한 뒤 원본과 바이트가 같은 다운로드 중복본을 정리한다. `.p8` 파일은 Git에서도 제외한다.

Apple Distribution 인증서의 개인키는 macOS 키체인에서 관리한다. 별도 `.p12` 파일로 내보내 중복 보관하지 않는다. Xcode가 관리하는 프로비저닝 프로파일과 빌드 산출물은 Xcode의 표준 경로를 유지한다. 프로젝트의 `Configuration/TestFlightExport.plist`는 비밀키가 없는 배포 설정이므로 Git에서 계속 관리한다.

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

## API 연결 검증

2026-09-15 사용자가 다운로드한 팀 API 키를 로컬 보안 경로에 연결했고, 실제 API 조회로 **1.0 (2)**의 `Personal` 설치 가능 상태를 확인했다. 이어서 **1.0 (3)**의 자동화 19개·Release 코어 66개·UI 11개, 총 96개 테스트와 아카이브가 성공했다.

최초 export는 `Cloud signing permission error`로 실패했다. 이 Mac에는 개발용 인증서만 있었으며, 제품 개발 권한의 API 키에는 클라우드 배포 서명과 배포 프로파일 생성 권한이 없었다. 사용자 승인 후 Xcode의 **Apple Accounts → JiSang Park → Manage Certificates → Apple Distribution**에서 배포 인증서를 생성했다. 기존 Xcode 계정으로 로컬 export를 한 번 수행하여 새 인증서를 포함하는 배포 프로파일도 준비했다. [Apple의 로컬 배포 서명 안내](https://developer.apple.com/help/account/certificates/cloud-managed-certificates).

그 뒤 같은 아카이브와 기존 export 설정으로 API 키 인증 업로드에 성공했다(**03:53:31 UTC**, `EXPORT SUCCEEDED`). Apple 처리 완료 후 API가 `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING` 및 `Personal` 그룹 포함을 확인했고 **READY**로 종료했다. **1.0 (3)**은 내부 테스트에서 설치 가능하다.

이 Mac에서는 이후 기본 `deploy` 명령을 사용한다. 다른 Mac으로 옮기거나 인증서·프로파일이 만료되면 로컬 서명 준비가 다시 필요하다. 현재 인증서와 대응 프로파일 만료는 **2027-09-15**다. API 키 권한을 확대하지 않았다.

검증 기록: `~/Library/Developer/PentaphorDeliveries/20260915-033747-co94ddgh/`. `Pentaphor.xcarchive`, `ExportOptions.plist`, `delivery.json`, 96개 테스트 로그, `local-profile-setup.log`, 최종 업로드 로그 `upload-provisioned.log`를 보존했다. 실패 로그 `upload.log`, `upload-local-signing.log`는 이전 시도의 진단 기록이다.
