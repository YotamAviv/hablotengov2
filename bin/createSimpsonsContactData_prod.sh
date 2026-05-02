#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Creating Simpsons Contact Data for Hablotengo (PRODUCTION) ==="
echo "Requires: ../simpsonsPublicKeys.json and ../simpsonsPrivateKeys.json (run nerdster14/bin/createSimpsonsDemoData.sh first)"
echo ""

python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py

python3 bin/chrome_widget_runner.py \
    -t lib/dev/simpsons_demo.dart \
    --dart-define=EMULATOR=false \
    --headless
