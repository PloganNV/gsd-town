#!/usr/bin/env bash
# Syntax check for all bash modules.
# Run: bash test/bash/01-syntax.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

check_syntax() {
  local file="$1"
  if bash -n "$file" 2>/dev/null; then
    echo "  ok — $(basename "$file")"
    PASS=$((PASS + 1))
  else
    echo "  FAIL — $(basename "$file")"
    bash -n "$file" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

echo "bash syntax checks:"
check_syntax "$REPO_ROOT/lib/gastown.sh"
check_syntax "$REPO_ROOT/lib/auto-setup.sh"
check_syntax "$REPO_ROOT/lib/bead-state.sh"
check_syntax "$REPO_ROOT/lib/seance.sh"

echo ""
echo "results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
