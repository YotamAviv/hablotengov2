#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "=== Building Flutter web app ==="
flutter build web

echo ""
echo "=== Serving at http://localhost:8770 ==="
fuser -k 8770/tcp 2>/dev/null && echo "Killed previous server on 8770" || true
echo "Open: http://localhost:8770/?fire=emulator"
echo ""
python3 -m http.server 8770 --directory build/web
