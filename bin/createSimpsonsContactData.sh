#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Creating Simpsons Contact Data for Hablotengo ==="
echo "Requires: hablotengo emulator running (Firestore 8082, Functions 5003)"
echo "Requires: ../simpsonsPublicKeys.json (run nerdster14/bin/createSimpsonsDemoData.sh first)"
echo ""

# Generate lib/dev/simpsons_public_keys.dart and functions/simpsons_keys.json
# from the shared public key file.
python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_server_keys.py

python3 bin/chrome_widget_runner.py --headless -t lib/dev/simpsons_demo.dart 2>&1
