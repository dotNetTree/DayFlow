#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
build_app() {
  xcodebuild -project DayFlow.xcodeproj -scheme DayFlow -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO "$@" build
}
# 제한된 실행 환경에서만 선택적으로 컴파일러 플러그인 샌드박스를 끕니다.
if [[ "${DAYFLOW_SWIFT_DISABLE_SANDBOX:-0}" == "1" ]]; then
  swift test --disable-sandbox -Xswiftc -disable-sandbox
  build_app 'OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox'
else
  swift test --disable-sandbox
  build_app
fi
