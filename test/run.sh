#!/usr/bin/env bash
# Run all gsd-town tests.
# Usage: bash test/run.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FAIL=0

echo "=== bash tests ==="
for test_file in test/bash/*.sh; do
  echo ""
  echo "--- $test_file ---"
  if ! bash "$test_file"; then
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== cli tests ==="
if ! node --test test/cli/*.test.js 2>&1; then
  FAIL=$((FAIL + 1))
fi

# Integration tests — only run if GSD_TOWN_INTEGRATION=1 (requires live daemon)
if [ "${GSD_TOWN_INTEGRATION:-0}" = "1" ]; then
  echo ""
  echo "=== integration tests ==="
  for test_file in test/integration/*.sh; do
    echo ""
    echo "--- $test_file ---"
    if ! bash "$test_file"; then
      FAIL=$((FAIL + 1))
    fi
  done
else
  echo ""
  echo "=== integration tests ==="
  echo "  skipped (set GSD_TOWN_INTEGRATION=1 to run against live daemon)"
fi

echo ""
if [ $FAIL -eq 0 ]; then
  echo "✓ all tests passed"
  exit 0
else
  echo "✗ $FAIL test suite(s) failed"
  exit 1
fi
