#!/bin/bash
# Keep automated tests off the simulator used for interactive Xcode runs.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
lock_dir="${TMPDIR:-/tmp}/clove-automated-tests.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
    echo "Another Clove test run is active ($lock_dir)." >&2
    exit 1
fi
simulator_id=""
cleanup() {
    if [[ -n "$simulator_id" ]]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
    fi
    rmdir "$lock_dir"
}
trap cleanup EXIT

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
runtime_id="$(xcrun simctl list runtimes --json | python3 -c '
import json, sys
sdk = sys.argv[1]
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]
if not runtimes:
    sys.exit("No available iOS Simulator runtime. Install one in Xcode Settings.")
def version(runtime):
    return tuple(int(n) for n in runtime["version"].split("."))
matching = [r for r in runtimes if r["version"].split(".")[:2] == sdk.split(".")[:2]]
print(max(matching or runtimes, key=version)["identifier"])
' "$sdk_version")"
simulator_name="Clove Automated Tests"
simulator_id="$(xcrun simctl list devices --json | python3 -c '
import json, sys
for device in json.load(sys.stdin)["devices"].get(sys.argv[1], []):
    if device["name"] == sys.argv[2] and device.get("isAvailable"):
        print(device["udid"])
        break
' "$runtime_id" "$simulator_name")"
if [[ -z "$simulator_id" ]]; then
    simulator_id="$(xcrun simctl create "$simulator_name" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$runtime_id")"
fi

# Wait for SpringBoard and migration to finish before asking Xcode to launch.
xcrun simctl bootstatus "$simulator_id" -b
xcodebuild -project "$project_dir/Clove.xcodeproj" -scheme Clove \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "${TMPDIR:-/tmp}/clove-automated-tests-derived-data" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    "$@" test
