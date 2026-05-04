#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Creating Simpsons Contact Data for Hablotengo (PRODUCTION) ==="
echo "Requires: ../simpsonsPublicKeys.json and ../simpsonsPrivateKeys.json (run nerdster14/bin/createSimpsonsDemoData.sh first)"
echo ""

# Clear saved Hablo delegate keys before generating fresh ones.
#
# simpsonsHabloKeys.json persists across both emulator and prod runs. If it exists
# (e.g. from a prior emulator run), gen_simpsons_private_keys_dart.py merges those
# keys in, and simpsons_demo.dart reuses them without publishing delegate statements
# to OOU. Since the emulator keys were published to the OOU emulator (not OOU prod),
# buildContact fetches from OOU prod, finds no delegate statements, and returns null
# for every identity — contact data is written but invisible.
#
# Deleting the file here forces the widget runner to generate new delegate keys,
# publish them to OOU production, and write contact data against those fresh keys.
HABLO_KEYS="$(dirname "$0")/../../simpsonsHabloKeys.json"
if [ -f "$HABLO_KEYS" ]; then
  rm "$HABLO_KEYS"
  echo "Cleared simpsonsHabloKeys.json (had stale delegate keys from a prior run)"
fi

python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py

tmpfile=$(mktemp)
python3 bin/chrome_widget_runner.py \
    -t lib/dev/simpsons_demo.dart \
    --dart-define=EMULATOR=false \
    --headless | tee "$tmpfile"
python3 bin/save_hablo_delegate_keys.py "$tmpfile"
rm "$tmpfile"
