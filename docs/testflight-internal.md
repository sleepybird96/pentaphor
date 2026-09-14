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

## 다음 빌드 올리기

Xcode에 해당 개발자 계정이 로그인되어 있어야 한다. 저장만으로 배포되지 않으며, 변경을 검증한 뒤 새 아카이브를 만들고 업로드한다. 아카이브 경로는 매번 새 이름을 사용한다.

```sh
xcodebuild archive \
  -project Pentaphor.xcodeproj \
  -scheme Pentaphor \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/Pentaphor-Next.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath /tmp/Pentaphor-Next.xcarchive \
  -exportOptionsPlist Configuration/TestFlightExport.plist \
  -exportPath /tmp/Pentaphor-Next-Upload \
  -allowProvisioningUpdates
```

두 번째 명령은 Apple 서버에 실제로 업로드한다. 내보내기 설정은 **내부 테스트 전용**이며, 빌드 번호는 Xcode가 관리한다. 업로드가 성공해도 Apple의 처리가 끝나야 TestFlight에 나타난다. `Personal` 그룹은 처리 완료된 Xcode 업로드 빌드를 자동으로 받도록 설정했다.

## 배포 설정

앱 타깃의 `TARGETED_DEVICE_FAMILY`를 `1`로 명시한다. XcodeGen은 프로젝트 공통 설정만 지정하면 앱 타깃에 `1,2`를 생성할 수 있어, 아이폰 세로 전용 화면이 아이패드 멀티태스킹 검증에서 거절된다.

`ITSAppUsesNonExemptEncryption = false`는 현재 코드와 의존성이 별도 암호화 기능을 구현하지 않는다는 확인에 기반한다. 암호화 기능이나 SDK를 추가할 때 다시 확인한다. [Apple의 암호화 항목 안내](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)

TestFlight의 같은 번들 ID 앱으로 업데이트하며, 기존 앱을 먼저 삭제하지 않는다. 사용자 기록은 기기에 저장되며 동기화/백업 기능은 아직 없다.
