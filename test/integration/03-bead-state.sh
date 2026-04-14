#!/usr/bin/env bash
# Integration test: bead-state.sh against live beads database.
# Run: bash test/integration/03-bead-state.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

export PATH="$HOME/.local/bin:$HOME/go/bin:/opt/homebrew/bin:$PATH"
source "$REPO_ROOT/lib/gastown.sh"
source "$REPO_ROOT/lib/bead-state.sh"

echo "integration: bead-state module"

# Find rig
RIG=""
for candidate in gastown hq ; do
  if cd ~/gt && gt rig list 2>/dev/null | grep -qw "$candidate"; then
    RIG="$candidate"
    break
  fi
done

if [ -z "$RIG" ]; then
  echo "  SKIP — no rig available"
  exit 0
fi

export GT_RIG_DIR="$HOME/gt/$RIG/mayor/rig"

# Create a test bead we can read from
TEST_NOTES="Integration test content for bead-state.sh read test"
BEAD_ID=$(create_plan_bead "test" "beadstate" "bead-state integration test" "$TEST_NOTES" 2>&1 | tail -1)

if [[ ! "$BEAD_ID" =~ ^[a-z]+-[a-z0-9]+$ ]]; then
  echo "  FAIL — could not create test bead: $BEAD_ID"
  exit 1
fi

# Test: read_plan_result_from_bead returns the notes
result=$(read_plan_result_from_bead "$BEAD_ID" 2>&1)
if echo "$result" | grep -q "Integration test content"; then
  echo "  ok — read_plan_result_from_bead returns bead notes"
  PASS=$((PASS + 1))
else
  echo "  FAIL — read_plan_result_from_bead output: $result"
  FAIL=$((FAIL + 1))
fi

# Test: bd show --json returns array (research finding)
# Note: bd_cmd returns the path to bd, not a wrapper. Invoke bd directly from rig dir.
BD_BIN=$(bd_cmd)
if (cd "$GT_RIG_DIR" && "$BD_BIN" show "$BEAD_ID" --json 2>/dev/null) | python3 -c "import sys, json; d = json.load(sys.stdin); assert isinstance(d, list), f'expected list, got {type(d)}'" 2>/dev/null; then
  echo "  ok — bd show --json returns array (research was correct)"
  PASS=$((PASS + 1))
else
  echo "  FAIL — bd show --json did not return array"
  FAIL=$((FAIL + 1))
fi

# Cleanup
(cd "$GT_RIG_DIR" && "$BD_BIN" close "$BEAD_ID" --reason "integration test cleanup" 2>/dev/null || true)

echo ""
echo "results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
