#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
PASS=0
FAIL=0
FAILED_NAMES=""
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

ok()   { printf "\u2713"; PASS=$((PASS+1)); }
fail() { printf "\u2717"; FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES $1"; }

run_check() {
  local name="$1"; shift
  if "$@" &>"$TMPDIR/$name" 2>&1; then ok; else fail "$name"; fi
}

run_check "lint" make lint
run_check "test" make test

echo ""
if [ "$FAIL" -eq 0 ]; then
  printf "\u2713 %d PASSED\n" "$PASS"
  exit 0
else
  printf "\u2717 %d FAILED\n\n" "$FAIL"
  for name in $FAILED_NAMES; do
    if [ -s "$TMPDIR/$name" ]; then
      printf "[\u2717] %s\n" "$name"
      sed 's/^/  /' "$TMPDIR/$name"
      echo ""
    fi
  done
  exit 1
fi
