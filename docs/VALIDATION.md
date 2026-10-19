# 검증 결과 — 2026-10-19

## DF-001 / DF-002 통합 검증

환경: Xcode 27.1, Swift 6.4, macOS. 두 작업을 병렬 구현한 뒤 공유 화면과 Store를 통합했습니다.

실행 명령:

```sh
DAYFLOW_SWIFT_DISABLE_SANDBOX=1 ./scripts/verify.sh
```

- Swift Package 테스트: **22개 통과, 실패 0개**.
- 기존 모델·저장 테스트 4개: 입력 검증, 자정 경계, JSON 저장·읽기, 손상 파일.
- 검색 테스트 5개: 제목/메모, 영문 대소문자, 한국어, 공백, 날짜 경계, 완료 일정 포함, 정렬.
- 알림 테스트 8개: 이전 JSON 호환, 미래 일정과 32개 상한, 권한 요청·실패·재시도, 중복 없는 갱신, 실패 시 이전 예약 정리, 완료/끄기/삭제, 직렬 처리.
- Store 통합 테스트 5개: 실제 저장 실패·삭제 실패 시 목록과 예약 보존, 손상 로드 보호, 저장 성공 후 예약, 데모 저장 파일 격리, 이전 동기화 보고가 권한 허용 결과를 덮어쓰지 않음.
- iOS Simulator generic 대상 Debug 빌드: **성공** (arm64 / x86_64).
- git diff --check: 통과.

이전 초기 빌드의 Swift 매크로 오류는 제한된 로컬 환경에서 컴파일러에 -disable-sandbox를 선택적으로 전달하여 해결했습니다. 기본 CI에는 이 옵션을 적용하지 않습니다.

## 아직 확인하지 못한 항목

- 시뮬레이터 실행과 화면 수동 QA: 미검증. 현재 CoreSimulator 서비스에 연결하지 못하고 런타임을 검색하지 못합니다. 빌드 성공과 실제 화면 동작은 별개입니다.
- 실제 기기 알림의 전면/백그라운드 도착, 설정 앱 이동, Focus·알림 요약 영향: 미검증.
- 앱 재실행 후 실제 앱 데이터와 시스템 예약 일치, 시간대 변경 후 실제 알림 도착: 미검증. 관련 순수 로직 및 Store는 자동 테스트로 확인했습니다.
- 따라서 BACKLOG와 TASK는 구현 완료 / QA 대기로 표시합니다. 완료 체크박스는 수동 화면 검증까지 수행한 최종 승인 기록으로 남겨두었습니다.
- GitHub CI 결과는 원격 실행 결과에서 별도로 확인해야 합니다.

## 알림 설계 근거

- Apple 권한 요청 문서: https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications
- Apple 로컬 예약 문서: https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app

32개는 제품 자체의 예약 상한이며 Apple 시스템 상한을 뜻하지 않습니다. 앱이 계속 열리지 않으면 대기 항목을 자동 보충하지 못합니다.
