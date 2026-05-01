#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_restructure_web.sh"

echo "=== Building Flutter web app (base href /app/) ==="
flutter build web --base-href /app/

echo ""
restructure_web

echo ""
echo "=== Deploying to Firebase Hosting ==="
firebase deploy --only hosting --project=hablotengo

echo ""
echo "=== Done ==="
echo "Home:    https://hablotengo.com"
echo "Web app: https://hablotengo.com/app"
