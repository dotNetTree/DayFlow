#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
if [[ -n "${DAYFLOW_SIMULATOR_ID:-}" ]]; then
  simulator_id="$DAYFLOW_SIMULATOR_ID"
else
  simulator_id="$(xcrun simctl list devices available --json | python3 scripts/select_simulator.py)"
fi
result_path="$PWD/.build/UIResults-$(date +%s).xcresult"
run_tests() {
  xcodebuild -project DayFlow.xcodeproj -scheme DayFlow -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath .build/UIBuild -resultBundlePath "$result_path" \
    -parallel-testing-enabled NO -only-testing:DayFlowUITests \
    CODE_SIGNING_ALLOWED=NO "$@" test
}
printf 'UI test simulator: %s\nResult bundle: %s\n' "$simulator_id" "$result_path"
if [[ "${DAYFLOW_SWIFT_DISABLE_SANDBOX:-0}" == "1" ]]; then
  run_tests 'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
else
  run_tests
fi
