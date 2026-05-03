#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

# Fixed port so Nerdster can link here (nerdsterAppUrl emulator → localhost:8765,
# hablotengo links to itself at localhost:8770).
echo "Open: http://localhost:8770/?fire=emulator"
flutter run -d chrome --web-port=8770
