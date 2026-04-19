#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "=== Cloud Function tests ==="
(cd functions && npm test)
