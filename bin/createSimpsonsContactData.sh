#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Creating Simpsons Contact Data for Hablotengo ==="
echo "Requires: hablotengo emulator running (Firestore 8082, Functions 5003)"
echo "Requires: oneofus emulator running (Functions 5002)"
echo "Requires: ../simpsonsPublicKeys.json and ../simpsonsPrivateKeys.json (run nerdster14/bin/createSimpsonsDemoData.sh first)"
echo ""

# Generate lib/dev/simpsons_public_keys.dart, lib/dev/simpsons_private_keys.dart,
# and functions/simpsons_keys.json from the shared key files.
python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py

python3 bin/chrome_widget_runner.py --headless -t lib/dev/simpsons_demo.dart \
    --dart-define=EMULATOR=true 2>&1
