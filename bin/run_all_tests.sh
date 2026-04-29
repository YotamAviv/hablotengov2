#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "=== Cloud Function tests ==="
(cd functions && npm test)

echo "=== oneofus_common Package Tests ==="
(cd packages/oneofus_common && flutter test)
