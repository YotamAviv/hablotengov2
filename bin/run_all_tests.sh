#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "=== Cloud Function tests ==="
(cd functions && npm test)

# TODO: Re-introduce Chrome/UI testing when the new model has a testable UI flow.
# echo "=== Chrome widget test ==="
# python3 bin/chrome_widget_runner.py -t lib/dev/cloud_source_web_test.dart

echo "=== Fake-fire widget test ==="
python3 bin/chrome_widget_runner.py -t lib/dev/fake_fire_web_test.dart
