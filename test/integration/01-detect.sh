#!/usr/bin/env bash
# Integration test: gastown detection against live daemon.
# Requires: gt daemon running, bd installed, tmux installed.
# Run: bash test/integration/01-detect.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

# Make sure binaries are on PATH
export PATH="$HOME/.local/bin:$HOME/go/bin:/opt/homebrew/bin:$PATH"

source "$REPO_ROOT/lib/gastown.sh"

echo "integration: detection against live daemon"

# Test 1: detect_gastown returns "true" when daemon is running
result=$(detect_gastown)
if [ "$result" = "true" ]; then
  echo "  ok — detect_gastown returns true"
  PASS=$((PASS + 1))
else
  echo "  FAIL — detect_gastown returned: $result"
  FAIL=$((FAIL + 1))
fi

# Test 2: gt_cmd can run basic commands
if gt_cmd version >/dev/null 2>&1; then
  echo "  ok — gt_cmd version works"
  PASS=$((PASS + 1))
else
  echo "  FAIL — gt_cmd version failed"
  FAIL=$((FAIL + 1))
fi

# Test 3: bd is reachable
if bd_cmd list --flat --json >/dev/null 2>&1; then
  echo "  ok — bd_cmd list works"
  PASS=$((PASS + 1))
else
  echo "  FAIL — bd_cmd list failed"
  FAIL=$((FAIL + 1))
fi

# Test 4: check_capacity returns ok/full
cap=$(check_capacity)
if [ "$cap" = "ok" ] || [ "$cap" = "full" ]; then
  echo "  ok — check_capacity returned: $cap"
  PASS=$((PASS + 1))
else
  echo "  FAIL — check_capacity returned unexpected: $cap"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
