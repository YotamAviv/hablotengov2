#!/bin/bash
# Runs the full Hablotengo test suite.
#
# Tests run against the latest hablotengo emulator export in exports/.
# That export should be a golden export created by bin/create_golden_export.sh —
# NOT a production export. Using a golden export means the Simpsons key files
# (simpsons_keys.json, simpsons_public_keys.dart, etc.) are consistent with the
# emulator data, but backwards compatibility with real production data is NOT tested.
#
# TODO: support running the test suite against a production export as well, to
# catch regressions in backwards compatibility with real data.
cd "$(dirname "$0")/.."

FAILED_TESTS=()
PASSED_TESTS=()

# Prerequisites:
#   Firebase emulators: ./bin/start_emulator.sh (hablotengo) — started from a golden export
#                       oneofusv22/bin/start_emulator.sh (one-of-us-net)
#                       karennet/bin/start_emulator.sh (karennet, port 5004)
echo "Checking prerequisites..."
curl -s --max-time 3 http://localhost:8082/ > /dev/null \
    || { echo "ERROR: Hablo Firebase emulator not responding on port 8082."; exit 1; }
curl -s --max-time 3 http://localhost:5002/ > /dev/null \
    || { echo "ERROR: OneOfUs emulator not responding on port 5002."; exit 1; }
curl -s --max-time 3 http://localhost:5004/ > /dev/null \
    || { echo "ERROR: Karennet emulator not responding on port 5004."; exit 1; }
[ -f lib/dev/simpsons_private_keys.dart ] \
    || { echo "ERROR: lib/dev/simpsons_private_keys.dart missing. Run: python3 bin/gen_simpsons_private_keys_dart.py"; exit 1; }
[ -f ../simpsonsHabloKeys.json ] \
    || { echo "ERROR: simpsonsHabloKeys.json missing. Run: bin/createSimpsonsContactData.sh"; exit 1; }
grep -q 'homer2-hablo0' lib/dev/simpsons_private_keys.dart \
    || { echo "ERROR: homer2-hablo0 missing from simpsons_private_keys.dart. Run: python3 bin/gen_simpsons_private_keys_dart.py"; exit 1; }
echo "Prerequisites OK."
echo ""

# 1. oneofus_common package tests
# --verbose fixes exit-255 in non-TTY; grep strips Flutter tool internals (lines starting with '[')
echo "=== Running oneofus_common Package Tests ==="
(cd packages/oneofus_common && flutter test --verbose 2>&1) | grep -v "^\["
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    PASSED_TESTS+=("oneofus_common tests")
else
    FAILED_TESTS+=("oneofus_common tests")
fi
echo ""

# 2. Contacts web test (Chrome, sentinel-based)
echo "=== Running Contacts Web Test (Chrome) ==="
if python3 bin/chrome_widget_runner.py -t lib/dev/contacts_web_test.dart; then
    PASSED_TESTS+=("contacts_web_test (chrome)")
else
    FAILED_TESTS+=("contacts_web_test (chrome)")
fi
echo ""

# 3. Contact write test (Chrome, sentinel-based).
# Runs before CF tests because it mutates emulator data and restores it at the end.
echo "=== Running Contact Write Test (Chrome) ==="
if python3 bin/chrome_widget_runner.py -t lib/dev/contact_write_test.dart; then
    PASSED_TESTS+=("contact_write_test (chrome)")
else
    FAILED_TESTS+=("contact_write_test (chrome)")
fi
echo ""

# 4. Cloud Function tests — run last so they see emulator data restored by contact_write_test.
echo "=== Running Cloud Function Tests ==="
if (cd functions && npm test); then
    PASSED_TESTS+=("Cloud Function tests")
else
    FAILED_TESTS+=("Cloud Function tests")
fi
echo ""

# 5. Trust pipeline tests (require OOU + karennet emulators).
echo "=== Running Trust Pipeline Tests ==="
if (cd functions && node --test test/trust_pipeline.test.js); then
    PASSED_TESTS+=("trust_pipeline tests")
else
    FAILED_TESTS+=("trust_pipeline tests")
fi
echo ""

# 6. Multi-target trust pipeline tests (require OOU emulator).
echo "=== Running Multi-Target Trust Pipeline Tests ==="
if (cd functions && node --test test/multi_target_trust.test.js); then
    PASSED_TESTS+=("multi_target_trust tests")
else
    FAILED_TESTS+=("multi_target_trust tests")
fi
echo ""

# Summary
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo "PASSED (${#PASSED_TESTS[@]}):"
for test in "${PASSED_TESTS[@]}"; do
    echo "  ✅ $test"
done
echo ""
echo "FAILED (${#FAILED_TESTS[@]}):"
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo "  (none)"
else
    for test in "${FAILED_TESTS[@]}"; do
        echo "  ❌ $test"
    done
fi
echo "========================================"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    exit 1
fi
