#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

echo "=== Starting hablotengo emulator (Firestore 8082, Functions 5003, UI 4002) ==="
nohup firebase --project=demo-hablotengo emulators:start --only functions,firestore \
    > "$REPO_DIR/hablotengo_emulator.log" 2>&1 &

echo $! > "$REPO_DIR/.hablotengo_emulator.pid"
echo "Started. Log: hablotengo_emulator.log"
echo "UI: http://localhost:4002"
echo "Stop with: ./bin/stop_emulator.sh"

adb reverse tcp:5003 tcp:5003 && echo "adb reverse tcp:5003 set up" || echo "WARNING: adb reverse tcp:5003 failed (Android emulator not running?)"
adb reverse tcp:8082 tcp:8082 && echo "adb reverse tcp:8082 set up" || echo "WARNING: adb reverse tcp:8082 failed (Android emulator not running?)"
