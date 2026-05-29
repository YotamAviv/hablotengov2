#!/bin/bash
# Checks that shared functions/ files are identical across repos.
# Run from any directory — paths are resolved relative to this script.
cd "$(dirname "$0")/.."

# Shared across all 3 repos
ALL3=(
  export.js
  write2.js
  statement_fetcher.js
  verify_util.js
)

# Shared between hablotengo and nerdster only
HABLO_NERD=(
  trust_pipeline.js
  trust_logic.js
  oneofus_source.js
  delegate_resolver.js
)

ok=true

check() {
  local file="$1"
  local a="functions/$file"
  local b="$2/functions/$file"
  if ! diff -q "$a" "$b" > /dev/null 2>&1; then
    echo "OUT OF SYNC: $file (hablotengo vs $(basename $2))"
    ok=false
  fi
}

for file in "${ALL3[@]}"; do
  check "$file" "../nerdster"
  check "$file" "../oneofus"
done

for file in "${HABLO_NERD[@]}"; do
  check "$file" "../nerdster"
done

$ok && echo "OK: all shared functions/ files in sync" || exit 1
