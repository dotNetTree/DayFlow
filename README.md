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

## DF-001 일정 검색

선택 날짜의 제목과 메모를 부분 검색합니다. 대소문자와 앞뒤 공백을 무시하며 검색어는 날짜 변경 시 유지됩니다. TASK는 docs/tasks/DF-001.md에 있습니다.

제한된 로컬 컴파일러 플러그인 환경에서는 `DAYFLOW_SWIFT_DISABLE_SANDBOX=1 ./scripts/verify.sh`로 검증합니다. 이 옵션은 기본 CI에는 적용하지 않습니다.
