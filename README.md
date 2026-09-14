# PENTAPHOR

매일 채우는 체크리스트보다, 자기 페이스로 이어가는 성장을 위한 iPhone 루틴 앱.

## 첫 개발 버전

- 커스텀 퀘스트 생성·수정·보관·복원, 주간·월간 목표
- 체력·지식·끈기·매력·용기에 완료당 최대 2포인트 배분
- 퀘스트별 2주/2개월째부터 연속 달성 기간마다 끈기 +1
- 월요일 00:00 새 주 시작, 월요일 09:00 전까지 명시적으로 지난주 기록 선택
- 달성·되돌리기·기록 내역·파라미터, 오각형 성장 연출과 햅틱
- 카테고리로 고르는 기존 아트 60종, 기기 내 SwiftData 저장

처음 실행하면 빈 퀘스트 목록으로 시작한다. 네트워크나 계정 없이 사용할 수 있다. 집계 시간대는 첫 실행 때 저장하고 유지한다. 이미 기록한 포인트와 목표는 스냅샷으로 보존한다. 해당 기간에 기록이 있으면 목표 변경은 다음 기간부터 적용한다.

퀘스트 목록에서 진행 횟수 아래의 **✎ 수정**을 누르면 이름·아트·목표·포인트를 수정할 수 있다. 그림이나 이름을 눌러도 같은 수정 화면이 열린다. 오른쪽 체크 버튼은 완료 기록용이다.

## 실행

검증 환경: Xcode 26.3, Swift 6.2.4, iOS 26.3.1 시뮬레이터. 배포 타깃은 iOS 17 이상이며, iOS 17 실기기 검증은 아직 하지 않았다.

1. `Pentaphor.xcodeproj`를 Xcode에서 연다.
2. `Pentaphor` scheme과 iPhone 시뮬레이터를 선택한다.
3. Run을 실행한다.

실제 iPhone 설치에는 Xcode의 Signing & Capabilities에서 본인의 개발자 Team을 선택하고 연결된 기기를 실행 대상으로 지정해야 한다. 현재 프로젝트에는 사용자가 선택한 Team을 유지하고 자동 서명을 설정했다. Bundle ID는 개발용 `app.pentaphor.personal`이다.

`project.yml`을 변경한 경우 XcodeGen으로 프로젝트를 다시 생성한다.

```sh
xcodegen generate
```

## 테스트

```sh
swift test --package-path Packages/PentaphorCore

xcodebuild test -project Pentaphor.xcodeproj -scheme Pentaphor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

사용 가능한 시뮬레이터 이름에 맞춰 destination을 바꿀 수 있다. 코어 테스트는 독립 Swift 패키지에서 실행한다. Xcode 앱 scheme은 UI 테스트를 실행한다.

UI 테스트는 DEBUG 전용 별도 저장소를 사용한다. `--ui-testing`으로 테스트 저장소를 선택하고 `--reset-test-store`를 함께 전달할 때 해당 테스트 저장소만 초기화한다. 일반 앱의 기록에는 영향을 주지 않는다.

## 구조와 개발 기록

- [기능 명세](docs/superpowers/specs/2026-09-11-ios-foundation-design.md): 규칙과 인수 조건
- [구현 계획](docs/superpowers/plans/2026-09-11-ios-foundation.md): 작업 순서와 검증 항목
- [TDD 기록](docs/development-log.md): 실제 RED/GREEN 결과
- [화면 검증](docs/native-ui-report.md), [스크린샷](docs/screenshots/)
- `Packages/PentaphorCore`: 기간 계산, 완료 원장, 보너스 산출, 저장 트랜잭션
- `Pentaphor`: SwiftUI 화면과 리소스 카탈로그
- `assets/quest-art/*.png`: 앱에서 사용하는 기존 아트 60종

저장은 변경 상태를 복사해 계산하고, 디스크 저장이 성공한 뒤 화면에 반영한다. 손상된 저장소나 지원하지 않는 버전은 빈 데이터로 덮어쓰지 않는다.

## 다음 개발 범위

월간 리캡, 알림, 동기화는 아직 구현하지 않았다. 사용자는 실제 iPhone에 첫 버전을 설치했다. 2026-09-14 확정한 오각형 아이콘을 앱 아이콘과 앱 내부 로고에 적용했다. TestFlight 배포 전에는 실기기 사용 검증과 배포 서명 및 App Store Connect 앱 정보 설정이 남아 있다.
