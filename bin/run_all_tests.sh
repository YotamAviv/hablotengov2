#!/bin/bash
cd "$(dirname "$0")/.."

FAILED_TESTS=()
PASSED_TESTS=()

# Prerequisites:
#   Firebase emulators: ./bin/start_emulator.sh (hablotengo)
#                       oneofusv22/bin/start_emulator.sh (one-of-us-net)
echo "Checking prerequisites..."
curl -s --max-time 3 http://localhost:8082/ > /dev/null \
    || { echo "ERROR: Hablo Firebase emulator not responding on port 8082."; exit 1; }
curl -s --max-time 3 http://localhost:5002/ > /dev/null \
    || { echo "ERROR: OneOfUs emulator not responding on port 5002."; exit 1; }
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
