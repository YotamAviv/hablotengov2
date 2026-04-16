#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
NERDSTER_DIR="$REPO_DIR/../nerdster14"

for pidfile in "$REPO_DIR/.hablotengo_emulator.pid" "$NERDSTER_DIR/.oneofus_emulator.pid"; do
  if [ -f "$pidfile" ]; then
    pid=$(cat "$pidfile")
    kill "$pid" 2>/dev/null && echo "Stopped PID $pid" || echo "PID $pid not running"
    rm -f "$pidfile"
  fi
done
