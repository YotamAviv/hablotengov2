#!/bin/bash
# Creates a golden emulator export for use in tests.
#
# This seeds the hablotengo emulator from scratch on empty emulators and exports
# the result. Tests restore from this export between runs (via reset_emulator.sh).
#
# NOTE: This produces a self-consistent but synthetic dataset — it does NOT test
# backwards compatibility with real production data. To test against production,
# run bin/start_emulator.sh --export to pull the latest prod data instead.
# TODO: support running the test suite against either a golden export or a prod export.
#
# Prerequisites: nerdster14, oneofus, and hablotengo emulators all running.
# Use --empty to start them fresh (recommended):
#   cd ~/src/github/nerdster14  && bin/start_emulator.sh --empty
#   cd ~/src/github/oneofusv22  && bin/start_emulator.sh --empty
#   cd ~/src/github/hablotengo  && bin/start_emulator.sh --empty

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
NERDSTER_DIR="$REPO_DIR/../nerdster14"

cd "$NERDSTER_DIR"
echo "=== Step 1: Create nerdster Simpsons demo data ==="
bin/createSimpsonsDemoData.sh

cd "$REPO_DIR"
echo ""
echo "=== Step 2: Generate Hablo key files ==="
python3 bin/gen_simpsons_public_keys_dart.py
python3 bin/gen_simpsons_private_keys_dart.py
python3 bin/gen_simpsons_server_keys.py

echo ""
echo "=== Step 3: Seed Simpsons contact data ==="
bin/createSimpsonsContactData.sh

echo ""
echo "=== Step 4: Export golden snapshot ==="
NOW=$(date +%y-%m-%d--%H-%M)
EXPORT_DIR="$REPO_DIR/exports/hablotengo-golden-$NOW"
firebase --project=hablotengo emulators:export "$EXPORT_DIR" --only firestore
echo "Golden export written: $EXPORT_DIR"
echo "Tests will use this automatically (it is the latest export in exports/)."
