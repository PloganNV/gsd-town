#!/usr/bin/env bash
# Drift smoke test: verify gastown CLI API surface is intact.
# Does NOT require a running daemon — only runs --help on each command.
# Exits 0 if all expected commands and flags are present.
# Exits 1 if any command or flag is missing (drift detected).
#
# Usage:
#   bash test/drift/01-api-surface.sh
#   GT_BIN=/path/to/gt bash test/drift/01-api-surface.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
FAIL_DETAILS=()

# Resolve gt binary: explicit env, then vendor build artifact, then PATH
if [ -n "${GT_BIN:-}" ]; then
  GT="$GT_BIN"
elif [ -f "$REPO_ROOT/vendor/gastown/gt" ]; then
  GT="$REPO_ROOT/vendor/gastown/gt"
elif command -v gt >/dev/null 2>&1; then
  GT="$(command -v gt)"
else
  echo "ERROR: gt binary not found. Set GT_BIN or build vendor/gastown first." >&2
  exit 1
fi

echo "drift: gastown API surface check"
echo "  binary: $GT"
echo "  commit: $(git -C "$(dirname "$GT")" rev-parse HEAD 2>/dev/null || echo "unknown")"
echo ""

# ---- helpers ---------------------------------------------------------------

pass() {
  echo "  ok   — $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL — $1"
  FAIL_DETAILS+=("$1")
  FAIL=$((FAIL + 1))
}

# Check that a command's --help exits 0 and optionally contains a string.
# Usage: check_help <label> <command...>
check_help() {
  local label="$1"; shift
  if "$@" --help >/dev/null 2>&1; then
    pass "$label --help exits 0"
  else
    fail "$label --help failed (command gone or broken)"
  fi
}

# Check that --help output for a command contains a specific flag string.
# Usage: check_flag <label> <flag> <command...>
check_flag() {
  local label="$1"
  local flag="$2"; shift 2
  local help_output
  help_output=$("$@" --help 2>&1 || true)
  if echo "$help_output" | grep -q -- "$flag"; then
    pass "$label has $flag flag"
  else
    fail "$label is missing $flag flag (drift: flag removed upstream)"
  fi
}

# ---- command existence checks ----------------------------------------------

echo "commands:"
check_help "gt sling"          "$GT" sling
check_help "gt convoy stage"   "$GT" convoy stage
check_help "gt polecat list"   "$GT" polecat list
check_help "gt done"           "$GT" done
check_help "gt daemon status"  "$GT" daemon status

# ---- flag checks -----------------------------------------------------------

echo ""
echo "flags:"

# gt sling: --no-convoy and --no-merge are critical for GSD-Town dispatch
# (see gastown.sh dispatch_plan_to_polecat)
check_flag "gt sling" "--no-convoy"  "$GT" sling
check_flag "gt sling" "--no-merge"   "$GT" sling

# gt convoy stage: --launch (auto-start convoy) and --json (parse output) required
# (see gastown.sh create_phase_convoy_and_dispatch)
check_flag "gt convoy stage" "--launch"  "$GT" convoy stage
check_flag "gt convoy stage" "--json"    "$GT" convoy stage

# gt polecat list: --json required for polling loop
check_flag "gt polecat list" "--json"  "$GT" polecat list

# gt daemon status: no special flags required — just command existence (checked above)

# ---- bd check (optional) ---------------------------------------------------

echo ""
echo "bd (optional):"
BD_BIN=""
if [ -n "${BD_BIN_PATH:-}" ]; then
  BD_BIN="$BD_BIN_PATH"
elif [ -f "$HOME/go/bin/bd" ]; then
  BD_BIN="$HOME/go/bin/bd"
elif command -v bd >/dev/null 2>&1; then
  BD_BIN="$(command -v bd)"
fi

if [ -n "$BD_BIN" ]; then
  if "$BD_BIN" --help >/dev/null 2>&1; then
    pass "bd --help exits 0"
    # --json is used in bd list, bd show calls
    check_flag "bd list" "--json"  "$BD_BIN" list
  else
    fail "bd --help failed"
  fi
else
  echo "  skip — bd not found (set BD_BIN_PATH or add ~/go/bin to PATH)"
fi

# ---- results ---------------------------------------------------------------

echo ""
echo "results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "drift detected:"
  for detail in "${FAIL_DETAILS[@]}"; do
    echo "  - $detail"
  done
  echo ""
  echo "Action: bump vendor/gastown or update gastown.sh to match new API."
  exit 1
fi

exit 0
