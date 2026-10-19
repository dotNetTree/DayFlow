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
- xcresult와 테스트별 스크린샷을 `ui-test-results` 아티팩트로 업로드함(7일 보관).

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
