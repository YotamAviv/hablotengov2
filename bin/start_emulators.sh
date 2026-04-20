#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

echo "=== Starting hablotengo emulators (Firestore 8082, Functions 5003, UI 4002) ==="
nohup firebase --project=demo-hablotengo emulators:start \
  > "$REPO_DIR/hablotengo_emulators.log" 2>&1 &
echo $! > "$REPO_DIR/.hablotengo_emulator.pid"
echo "Started. Log: hablotengo_emulators.log"

echo ""
echo "=== Starting oneofus emulators (Firestore 8083, Functions 5004, UI 4003) ==="
nohup firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start \
  > "$REPO_DIR/oneofus_emulators.log" 2>&1 &
echo $! > "$REPO_DIR/.oneofus_emulator.pid"
echo "Started. Log: oneofus_emulators.log"

echo ""
echo "Hablotengo UI: http://localhost:4002"
echo "Oneofus UI:    http://localhost:4003"
echo "App (after serve_web.sh): http://localhost:8770/?fire=emulator&demo=simpsons"
echo "Stop with: ./bin/stop_emulators.sh"
