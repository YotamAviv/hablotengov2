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
echo "Checking prerequisites..."
curl -s --max-time 3 http://localhost:8082/ > /dev/null \
    || { echo "ERROR: Hablo Firebase emulator not responding on port 8082."; exit 1; }
curl -s --max-time 3 http://localhost:5002/ > /dev/null \
    || { echo "ERROR: OneOfUs emulator not responding on port 5002."; exit 1; }
[ -f lib/dev/simpsons_private_keys.dart ] \
    || { echo "ERROR: lib/dev/simpsons_private_keys.dart missing. Run: python3 bin/gen_simpsons_private_keys_dart.py"; exit 1; }
echo "Prerequisites OK."
echo ""

# 1. Cloud Function tests
echo "=== Running Cloud Function Tests ==="
if (cd functions && npm test); then
    PASSED_TESTS+=("Cloud Function tests")
else
    FAILED_TESTS+=("Cloud Function tests")
fi
echo ""

# 2. oneofus_common package tests
echo "=== Running oneofus_common Package Tests ==="
if (cd packages/oneofus_common && flutter test); then
    PASSED_TESTS+=("oneofus_common tests")
else
    FAILED_TESTS+=("oneofus_common tests")
fi
echo ""

# 3. Contacts web test (Chrome, sentinel-based)
echo "=== Running Contacts Web Test (Chrome) ==="
if python3 bin/chrome_widget_runner.py -t lib/dev/contacts_web_test.dart; then
    PASSED_TESTS+=("contacts_web_test (chrome)")
else
    FAILED_TESTS+=("contacts_web_test (chrome)")
fi
echo ""

# 4. Equivalent key scenarios (homer / homer2) — fresh emulator state per scenario
_reset_for_equivalent() {
    echo "  Resetting emulator..."
    ./bin/stop_emulator.sh
    ./bin/start_emulator.sh
    echo "  Waiting for hablotengo emulator..."
    for i in {1..30}; do
        if curl -s --max-time 2 http://localhost:8082/ > /dev/null 2>&1; then
            echo "  Emulator ready."
            break
        fi
        sleep 2
        if [ "$i" -eq 30 ]; then
            echo "ERROR: Emulator did not start in time."; exit 1
        fi
    done
    ./bin/createSimpsonsContactData.sh
}

for scenario in a b c d e; do
    upper=$(echo "$scenario" | tr '[:lower:]' '[:upper:]')
    echo "=== Running Equivalent Scenario $upper (Chrome) ==="
    _reset_for_equivalent
    if python3 bin/chrome_widget_runner.py -t "lib/dev/equivalent_web_test_${scenario}.dart"; then
        PASSED_TESTS+=("equivalent_scenario_$upper (chrome)")
    else
        FAILED_TESTS+=("equivalent_scenario_$upper (chrome)")
    fi
    echo ""
done

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
