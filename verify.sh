#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
version=$(xcodebuild -version)
if [[ "$version" != $'Xcode 16.2\nBuild version 16C5032a' ]]; then
  echo "Select Xcode 16.2 (16C5032a) with DEVELOPER_DIR before release verification." >&2
  exit 1
fi
xcrun swift test --disable-automatic-resolution -Xswiftc -warnings-as-errors
destinations=$(xcodebuild -project TeBank.xcodeproj -scheme TeBank -showdestinations)
device=$(python3 -c 'import re, sys
for line in sys.stdin:
    if "Ineligible destinations" in line:
        break
    if "platform:iOS Simulator," in line and "name:iPhone" in line:
        match = re.search(r"id:\s*([A-Fa-f0-9-]{36})", line)
        if match:
            print(match.group(1))
            sys.exit(0)
sys.exit("No installed iPhone simulator is eligible in Xcode 16.2.")' <<< "$destinations")
arch=$(uname -m)
xcodebuild -project TeBank.xcodeproj -scheme TeBank -configuration Debug \
  -destination "platform=iOS Simulator,id=$device" \
  -parallel-testing-enabled NO ARCHS="$arch" CODE_SIGNING_ALLOWED=NO test
