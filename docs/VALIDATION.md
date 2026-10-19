# DF-005 검증 — 2026-10-19

## 실제 실행 결과

- [GitHub Actions 실행 #18](https://github.com/dotNetTree/DayFlow/actions/runs/39217157439): **전체 성공**.
- 검증한 코드 커밋: `0c2c53e9081288c93fee5ec4da00c34da21fb872`.
- 환경: macOS 15, Xcode 16.4, iOS 18.5 Simulator / iPhone SE (3rd generation).
- `./scripts/verify.sh`: Core 테스트 **4개 통과**, iOS 앱 빌드 성공.
- `./scripts/ui-test.sh`: 실제 화면 테스트 **3개 통과, 실패 0개**.
- 추가·수정·완료·완료 취소·삭제: 54.019초, 통과.
- 데모 재실행 초기화: 23.918초, 통과.
- 빈 제목·공백 입력 저장 차단 및 취소: 15.088초, 통과.
- 최초 성공 실행 #18의 xcresult·스크린샷 업로드는 숨김 폴더 제외 설정으로 누락됐습니다. 테스트 성공과 아티팩트 업로드 성공을 구분하며, 후속 수정에서 PNG 추출과 업로드 필수 검증을 추가했습니다. 새 업로드 결과는 별도 확인합니다.

이 기록과 TASK 상태를 갱신하는 후속 변경은 문서만 수정하며 위 테스트 코드와 앱 동작은 동일합니다.

## 로컬 검증

- Xcode 27.1 / Swift 6.4에서 Core 테스트 4개와 iOS Simulator generic 앱 빌드 성공.
- UI 타깃 build-for-testing 성공. 제한된 로컬 Swift 플러그인 실행을 위해 -disable-sandbox 옵션 사용.
- 로컬 실제 UI 실행은 CoreSimulator 서비스 연결 실패로 중단되어 CI에서 실행 검증함.
- 스크립트 문법, SDK와 호환되는 시뮬레이터 선택과 빈 목록 실패 처리도 확인함.

## 실행 중 발견해 수정한 문제

- SwiftUI 삭제 확인창이 같은 식별자의 부모/자식 버튼을 노출해 UI 테스트가 중복 매칭으로 실패함. 확인창 내부 firstMatch로 범위를 제한하고 실제 삭제까지 재검증함.
- Xcode 16.4에서는 동기 XCTest 준비/종료 override의 MainActor 격리가 맞지 않아 컴파일 실패함. 테스트 내부 MainActor 헬퍼로 변경해 호환성을 확인함.
- 자동 최신 환경 대신 macOS 15 / Xcode 16.4로 CI를 고정하고 호환 SDK 시뮬레이터 선택, 부팅 대기, ad-hoc 서명과 테스트 시간 제한을 적용함.

## 남은 범위

DF-005의 기본 화면 자동화는 완료했습니다. DF-001 검색과 DF-002 알림은 각 PR에 이 기반을 적용하고 해당 기능 시나리오를 추가해야 합니다. 이번 결과로 두 기능의 화면 QA까지 완료 처리하지 않습니다. 시각적 배치, 큰 글자, VoiceOver와 실제 기기 알림 도착은 별도 검증 대상입니다.

## 스크린샷 업로드 재검증

[후속 실행](https://github.com/dotNetTree/DayFlow/actions/runs/39219192919)에서 Core·UI 테스트와 PNG 추출·업로드 단계가 모두 성공했습니다. Artifacts API로 실제 파일의 존재, 0보다 큰 크기와 미만료 상태를 확인했습니다.

- [PNG 스크린샷 ZIP](https://github.com/dotNetTree/DayFlow/actions/runs/39219192919/artifacts/12170864161): ui-screenshots, 228,601 bytes.
- [Xcode 결과 번들](https://github.com/dotNetTree/DayFlow/actions/runs/39219192919/artifacts/12171362016): ui-test-results, 721,932 bytes.
- 보관 기간: 7일. 이 링크가 최초 누락된 실행 #18의 업로드 안내를 대체합니다.

## DF-001: DF-005 병합 후 충돌 해결

main의 UI 테스트 타깃, 접근성 식별자, CI와 스크린샷 업로드 설정을 유지하면서 DF-001 검색 소스를 Xcode 빌드에 추가했습니다. TASK별 검색 QA 문서와 DF-005 검증 이력을 함께 보존합니다.

재검증 결과: Core 테스트 9개(검색 5개 + 기존 4개) 통과, iOS Simulator generic 앱 빌드 성공, UI 테스트 타깃 build-for-testing 성공. 로컬 명령은 DAYFLOW_SWIFT_DISABLE_SANDBOX=1 ./scripts/verify.sh와 동일 옵션의 xcodebuild build-for-testing입니다. 로컬 시뮬레이터 실행은 미검증이며 CI에서 기존 UI 회귀 테스트를 재실행합니다. 이 변경은 기존 PR #2의 충돌 해결이며 검색 화면 QA를 자동 완료 처리하지 않습니다.

## DF-002: 검색·UI 테스트·개발 규칙 병합 후 충돌 해결

최신 main의 검색 로직과 UI 접근성 식별자·UI 테스트 타깃·CI·스크린샷 업로드 설정을 유지하면서 알림 화면과 Core Store를 통합했습니다. Xcode 검색 파일과 알림 파일의 참조 ID 충돌도 별도로 정리했습니다.

재검증 결과: Core 테스트 22개(알림 8개, Store 5개, 검색 5개, 기존 모델·저장 4개) 통과. iOS Simulator generic 앱 빌드와 UI 테스트 타깃 build-for-testing 성공. 제한된 로컬 환경에서 DAYFLOW_SWIFT_DISABLE_SANDBOX=1 ./scripts/verify.sh와 동일 옵션의 xcodebuild build-for-testing을 사용했습니다. 실제 UI 회귀 테스트는 CI에서 재실행하며 알림 전용 화면 QA와 실제 기기 수신은 이번 충돌 해결로 완료 처리하지 않습니다.

## DF-002 화면 QA 확장 — 2026-10-19

- 추가 코드: NotificationUITests 4개, 주요 단계 스크린샷, 테스트 전용 미래 데모 일정.
- 로컬 검증: Core 테스트 22개 통과, 앱 빌드 및 알림 UI 테스트를 포함한 build-for-testing 성공.
- 실제 시뮬레이터 실행: CI에서 후속 확인 예정. 컴파일 성공을 UI 실행 성공으로 처리하지 않음.
- 실기기 조회: devicectl이 CoreDeviceService 초기화 대기 중 시간 초과.
- 사용자 확인: 현재 실기기를 사용할 수 없음. 따라서 실제 권한 팝업, 설정 앱 복귀, 전면·백그라운드 수신과 실기기 예약 정리는 **미검증**.
- 전체 DF-002 상태는 QA 대기 유지. 새 PR 생성 및 기존 초안의 일반 PR 전환은 하지 않음.
