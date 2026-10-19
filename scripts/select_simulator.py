#!/usr/bin/env python3
"""사용 가능한 iPhone 시뮬레이터를 선택합니다. 특정 모델 이름에 의존하지 않습니다."""
import json
import re
import sys

def select_device(payload):
    candidates = []
    for runtime, devices in payload.get("devices", {}).items():
        if ".iOS-" not in runtime:
            continue
        version = tuple(map(int, re.findall(r"\d+", runtime.split(".iOS-")[-1])))
        for device in devices:
            if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
                candidates.append((version, device["name"], device["udid"]))
    if not candidates:
        raise ValueError("사용 가능한 iPhone 시뮬레이터가 없습니다. Xcode에서 iOS Simulator 런타임을 설치해주세요.")
    return sorted(candidates, reverse=True)[0][2]

if __name__ == "__main__":
    try:
        print(select_device(json.load(sys.stdin)))
    except (ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
