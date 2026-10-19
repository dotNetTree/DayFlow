# DayFlow — AI 개발 자동화를 위한 일정 관리 앱

SwiftUI iOS 앱과 AI 개발 규칙, 작업 목록, 검증 스크립트, GitHub Actions를 함께 제공하는 독립 프로젝트입니다. 외부 패키지나 API 키 없이 실행합니다.

## 실행

1. macOS의 Xcode에서 `DayFlow.xcodeproj`를 엽니다.
2. DayFlow 스킴과 iOS 17 이상 시뮬레이터를 선택하고 Run합니다.
3. 실기기는 Signing & Capabilities에서 본인의 Team과 고유 Bundle Identifier를 지정합니다.

일정 추가·수정·삭제, 완료 표시, 날짜별 조회, JSON 로컬 저장을 지원합니다. 메모와 시간이 겹치는 여러 일정도 저장할 수 있습니다. 종일·반복 일정, 알림, Apple 캘린더 연동, 서버 동기화는 아직 구현하지 않았습니다.

## 실행 모드

Xcode → Edit Scheme → Run → Arguments Passed On Launch에 설정합니다.

| 인자 | 동작 |
| --- | --- |
| 없음 | Application Support/DayFlow/schedules.json에 저장 |
| --demo | 예시 일정으로 시작하고 메모리에서만 변경 |
| --error-demo | 저장 실패를 재현하고 기존 목록 유지 |

`--demo --error-demo`를 함께 사용하면 실제 저장 파일을 읽지 않고 오류 흐름을 확인할 수 있습니다. 로컬 파일은 서버로 전송하지 않습니다. 앱 삭제 시 데이터가 사라질 수 있습니다.

## AI와 개발하는 방법

이 폴더를 AI 도구의 프로젝트로 열고 AGENTS.md를 적용합니다. docs/BACKLOG.md에서 한 작업을 선택해 docs/TASK_TEMPLATE.md 형식으로 요청하세요.

```text
AGENTS.md와 docs/BACKLOG.md를 읽고 DF-001을 구현해줘.
완료 조건을 충족하고 ./scripts/verify.sh를 실행해줘.
수행하지 못한 검증은 명시하고 작업 상태를 갱신해줘.
```

흐름: 작업 선택 → 관련 코드 조사 → 구현 → 핵심 테스트 → iOS 빌드 → 화면 확인 → 변경 리뷰 → 병합.

이 프로젝트의 자동화는 로컬 검증 명령과 push/PR 시 실행되는 CI입니다. AI가 백그라운드에서 작업을 자동 선택하거나 커밋·배포하는 기능은 포함하지 않습니다. GitHub 저장소에 올리면 `.github/workflows/ci.yml`이 실행됩니다. 별도의 정기 자동화는 등록하지 않았습니다.

## 검증

```sh
./scripts/verify.sh
```

Core만 확인할 때는 `swift test --disable-sandbox`를 실행합니다. 전체 스크립트는 macOS와 iOS Simulator SDK가 설치된 Xcode가 필요합니다. `--disable-sandbox`는 패키지 테스트 빌드의 플러그인 샌드박스 설정이며 앱의 보안 설정을 변경하지 않습니다.

## 구조

- App/: SwiftUI 화면과 관찰 가능한 Store
- Core/: 일정 모델, 날짜 필터, JSON 저장소. Xcode 앱과 Swift Package 테스트가 같은 소스를 사용
- Tests/: 입력 검증, 날짜 경계, 파일 저장·읽기, 손상 파일 테스트
- scripts/: 로컬/CI 공통 검증 진입점
- docs/: 기능 목록, 요청 템플릿, 수동 QA, 검증 결과

작은 초기 앱이므로 SwiftUI Observation을 사용합니다. 파일 I/O는 MainActor에서 동기 실행하므로 대량 데이터나 동기화를 도입할 때는 비동기 저장소로 변경해야 합니다.

## TASK별 PR 규칙

TASK마다 독립 브랜치와 PR을 작성합니다. 실제 자동 테스트·빌드·화면 QA·실기기 검증이 모두 통과한 뒤 PR을 작성합니다. 화면·실기기 QA가 남으면 새 초안 PR도 작성하지 않습니다. 여러 TASK의 동시 개발도 PR은 분리합니다. 병합과 배포는 별도 지시가 필요합니다.

## UI 반복 테스트 우선 개발

다음 진행 순서는 DF-005 → DF-001 검색 UI 검증 → DF-002 알림 UI 검증 → DF-004 → DF-003입니다. TASK 번호는 유지합니다. 기능 개발 전에 화면 시나리오와 기대 결과를 정의하고, 구현 후 UI 회귀 테스트를 통과시킵니다.

```sh
./scripts/verify.sh   # Core 테스트와 앱 빌드
./scripts/ui-test.sh  # 실제 시뮬레이터에서 XCUITest
```

UI 테스트는 --demo로 앱을 실행해 실제 화면을 조작합니다. 추가·수정·완료·삭제, 빈 제목/공백 입력 차단과 취소, 데모 재실행 초기화를 확인합니다. 각 테스트에서 스크린샷을 첨부하며 CI는 xcresult 결과 번들을 7일간 보관합니다. Actions 실행의 ui-test-results 아티팩트는 Xcode에서 열 수 있고, ui-screenshots 아티팩트는 PNG 이미지 ZIP으로 내려받아 볼 수 있습니다. 업로드할 파일이 없으면 CI를 실패 처리합니다.

선택한 Xcode의 SDK와 호환되는 사용 가능한 iPhone 시뮬레이터를 자동 선택합니다. CI는 macOS 15 / Xcode 16.4를 지정해 실행 환경을 고정합니다. UI 실행용 앱과 테스트 러너는 인증서 없이 ad-hoc 서명합니다. 필요하면 `DAYFLOW_SIMULATOR_ID=<UDID>`를 지정하세요. 컴파일러 플러그인의 로컬 sandbox 오류가 있는 경우 `DAYFLOW_SWIFT_DISABLE_SANDBOX=1`을 명령 앞에 붙일 수 있습니다. 시뮬레이터 서비스 자체가 동작하지 않으면 CI에서 실행해야 합니다.

이 TASK는 main 기준의 기본 화면 자동화를 제공합니다. 검색과 알림 PR은 이 기반이 반영된 뒤 해당 기능 시나리오를 추가해 검증해야 합니다. UI 테스트는 시각적 디자인 검토와 실제 기기의 알림 수신 확인을 대신하지 않습니다.

참고: [Apple XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation), [테스트 결과 번들](https://help.apple.com/xcode/mac/current/en.lproj/devc38fc7392.html)

## DF-001 일정 검색

선택 날짜의 제목과 메모를 부분 검색합니다. 대소문자와 앞뒤 공백을 무시하며 검색어는 날짜 변경 시 유지됩니다. TASK는 docs/tasks/DF-001.md에 있습니다.

제한된 로컬 컴파일러 플러그인 환경에서는 `DAYFLOW_SWIFT_DISABLE_SANDBOX=1 ./scripts/verify.sh`로 검증합니다. 이 옵션은 기본 CI에는 적용하지 않습니다.


## PR 생성 전 필수 완료 조건

자동 테스트 → iOS 빌드 → TASK별 화면 QA → 실제 iPhone 검증 → 결과·증거 기록 → TASK별 PR 순서로 진행합니다. 시뮬레이터나 Mock 성공은 실기기 검증을 대체하지 않습니다. 미검증 항목이 있으면 작업 브랜치에 보존하고 PR 생성을 보류합니다. 기존 초안 PR은 모든 검증 전 일반 PR로 전환하지 않습니다.
