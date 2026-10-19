# DF-005 검증 — 2026-10-19

- UI 타깃 build-for-testing: 성공 (Xcode 27.1, Swift 6.4, iOS Simulator generic).
- 명령에 OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' 사용: 제한된 로컬 환경의 Swift 플러그인 실행 오류 회피용.
- 로컬 UI 실제 실행: 시도했으나 CoreSimulator 서비스 연결 실패로 실행 전 중단. UI 테스트 성공으로 처리하지 않음.
- Core 테스트와 앱 빌드, GitHub CI 실제 UI 실행 결과는 후속 기록 예정.

CI는 실제 시뮬레이터에서 UI 테스트를 실행하며 xcresult와 스크린샷을 ui-test-results 아티팩트로 보관합니다. 이 TASK는 기본 앱 화면을 대상으로 하며 기존 DF-001/DF-002 PR의 검색·알림 화면 검증을 대신하지 않습니다.
