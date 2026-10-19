#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
if [[ -n "${DAYFLOW_SIMULATOR_ID:-}" ]]; then
  simulator_id="$DAYFLOW_SIMULATOR_ID"
else
  simulator_id="$(xcrun simctl list devices available --json | python3 scripts/select_simulator.py)"
fi
# 시뮬레이터 부팅을 별도로 기다려 테스트 시작 지연과 테스트 실패를 구분합니다.
python3 - "$simulator_id" <<'BOOT'
import subprocess
import sys
try:
    subprocess.run(["xcrun", "simctl", "bootstatus", sys.argv[1], "-b"], check=True, timeout=240)
except subprocess.TimeoutExpired:
    sys.exit("Simulator boot timed out after 240 seconds")
BOOT
result_path="$PWD/.build/UIResults-$(date +%s).xcresult"
run_tests() {
  xcodebuild -project DayFlow.xcodeproj -scheme DayFlow -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath .build/UIBuild -resultBundlePath "$result_path" \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 120 \
    -only-testing:DayFlowUITests \
    CODE_SIGNING_ALLOWED=NO "$@" test
}
printf 'UI test simulator: %s\nResult bundle: %s\n' "$simulator_id" "$result_path"
if [[ "${DAYFLOW_SWIFT_DISABLE_SANDBOX:-0}" == "1" ]]; then
  run_tests 'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
else
  run_tests
fi
