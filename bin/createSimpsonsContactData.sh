#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Creating Simpsons Contact Data for Hablotengo ==="
echo "Requires: hablotengo emulator running (Firestore 8082, Functions 5003)"
echo "Requires: oneofus emulator running (Functions 5002)"
echo "Requires: ../simpsonsPublicKeys.json and ../simpsonsPrivateKeys.json (run nerdster14/bin/createSimpsonsDemoData.sh first)"
echo ""

# Clear saved hablo delegate keys so the demo re-publishes them to the OOU emulator.
# If we skip this, the demo skips publishing delegate statements (because keys are
# already saved), but the OOU emulator was just cleared and has no record of them —
# causing buildContact to return null (404) for any identity.
HABLO_KEYS="$(dirname "$0")/../../simpsonsHabloKeys.json"
if [ -f "$HABLO_KEYS" ]; then
  rm "$HABLO_KEYS"
  echo "Cleared simpsonsHabloKeys.json"
fi
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py

tmpfile=$(mktemp)
python3 bin/chrome_widget_runner.py --headless -t lib/dev/simpsons_demo.dart \
    --dart-define=EMULATOR=true 2>&1 | tee "$tmpfile"
python3 bin/save_hablo_delegate_keys.py "$tmpfile"
python3 bin/gen_simpsons_private_keys_dart.py
rm "$tmpfile"
