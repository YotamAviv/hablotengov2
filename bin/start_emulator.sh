#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

EXPORT=false
EMPTY=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --export) EXPORT=true ;;
        --empty) EMPTY=true ;;
    esac
    shift
done

if [ "$EXPORT" = true ]; then
    NOW=$(date +%y-%m-%d--%H-%M)
    echo "=== Exporting hablotengo from production ==="
    mkdir -p exports
    gcloud config set project hablotengo
    gcloud firestore export gs://hablotengo/hablotengo-$NOW
    gsutil -m cp -r gs://hablotengo/hablotengo-$NOW exports/
    IMPORT="exports/hablotengo-$NOW"
elif [ "$EMPTY" = true ]; then
    IMPORT=""
else
    IMPORT=$(ls -td exports/hablotengo-* 2>/dev/null | head -1 || true)
fi

echo "=== Starting hablotengo emulator (Firestore 8082, Functions 5003, UI 4002) ==="
if [ -n "${IMPORT:-}" ]; then
    echo "Using import: $IMPORT"
    nohup firebase --project=hablotengo emulators:start --only functions,firestore --import "$IMPORT/" \
        > "$REPO_DIR/hablotengo_emulator.log" 2>&1 &
else
    echo "No import data found. Starting with empty data."
    nohup firebase --project=hablotengo emulators:start --only functions,firestore \
        > "$REPO_DIR/hablotengo_emulator.log" 2>&1 &
fi

echo $! > "$REPO_DIR/.hablotengo_emulator.pid"
echo "Started. Log: hablotengo_emulator.log"
echo "UI: http://localhost:4002"
echo "Stop with: ./bin/stop_emulator.sh"

adb reverse tcp:5003 tcp:5003 && echo "adb reverse tcp:5003 set up" || echo "WARNING: adb reverse tcp:5003 failed (Android emulator not running?)"
adb reverse tcp:8082 tcp:8082 && echo "adb reverse tcp:8082 set up" || echo "WARNING: adb reverse tcp:8082 failed (Android emulator not running?)"
