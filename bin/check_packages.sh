#!/bin/bash
# Checks that shared packages are identical across repos.
# Run from any directory — paths are resolved relative to this script.
cd "$(dirname "$0")/.."

DIFF_OPTS="-rq --exclude=*.lock --exclude=.dart_tool --exclude=.flutter-plugins* --exclude=build"

ok=true

check() {
  local label="$1"
  local a="$2"
  local b="$3"
  local out
  out=$(diff $DIFF_OPTS "$a" "$b" 2>&1)
  if [ -n "$out" ]; then
    echo "OUT OF SYNC: $label"
    echo "$out" | sed 's/^/  /'
    ok=false
  else
    echo "OK: $label"
  fi
}

check "oneofus_common (hablotengo vs nerdster)" \
  packages/oneofus_common \
  ../nerdster/packages/oneofus_common

check "oneofus_common (hablotengo vs oneofus)" \
  packages/oneofus_common \
  ../oneofus/packages/oneofus_common

check "nerdster_common (hablotengo vs nerdster)" \
  packages/nerdster_common \
  ../nerdster/packages/nerdster_common

$ok || exit 1
