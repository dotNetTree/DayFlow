#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ui-attachments
found=0
for result in .build/UIResults-*.xcresult; do
  if [[ -d "$result" ]]; then
    xcrun xcresulttool export attachments --path "$result" --output-path .build/ui-attachments
    found=1
  fi
done
if [[ "$found" == "0" ]]; then
  echo 'UI result bundle was not generated.' >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
screenshots = list(Path('.build/ui-attachments').rglob('*.png'))
print(f'Exported {len(screenshots)} PNG screenshots')
if not screenshots:
    raise SystemExit('No screenshots were exported; do not report artifact upload as complete.')
PY
