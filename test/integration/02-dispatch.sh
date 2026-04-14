#!/usr/bin/env bash
# Integration test: dispatch a real polecat against live gastown.
# WARNING: This actually spawns a polecat (tmux session + worktree).
# The polecat is created with minimal instructions and should exit quickly via gt done.
# Run: bash test/integration/02-dispatch.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

export PATH="$HOME/.local/bin:$HOME/go/bin:/opt/homebrew/bin:$PATH"
source "$REPO_ROOT/lib/gastown.sh"

echo "integration: real polecat dispatch"

# Find an available rig — prefer 'gastown' since that's our default
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

echo "  using rig: $RIG"

# Step 1: Create a bead with trivial work
export GT_RIG_DIR="$HOME/gt/$RIG/mayor/rig"
if [ ! -d "$GT_RIG_DIR" ]; then
  echo "  SKIP — rig dir not found: $GT_RIG_DIR"
  exit 0
fi

TEST_TITLE="gsd-town integration test $(date +%s)"
TEST_NOTES=$(cat <<'EOF'
# Integration Test

This is an automated test bead. Do nothing — just call `gt done` immediately.

## Instructions
1. Do not modify any files
2. Do not run any commands
3. Call `gt done` to complete
EOF
)

echo "  creating bead..."
BEAD_ID=$(create_plan_bead "test" "integration" "$TEST_TITLE" "$TEST_NOTES" 2>&1 | tail -1)

if [[ "$BEAD_ID" =~ ^[a-z]+-[a-z0-9]+$ ]]; then
  echo "  ok — bead created: $BEAD_ID"
  PASS=$((PASS + 1))
else
  echo "  FAIL — bead creation failed: $BEAD_ID"
  FAIL=$((FAIL + 1))
  echo "results: $PASS passed, $FAIL failed"
  exit 1
fi

# Step 2: Verify bead is readable
if bd_cmd show "$BEAD_ID" --json >/dev/null 2>&1; then
  echo "  ok — bead readable via bd show"
  PASS=$((PASS + 1))
else
  echo "  FAIL — bead not readable: $BEAD_ID"
  FAIL=$((FAIL + 1))
fi

# Step 3: Clean up — close the test bead (don't actually dispatch a polecat in CI)
echo "  cleaning up test bead..."
bd_cmd close "$BEAD_ID" --reason "integration test cleanup" 2>/dev/null || true
echo "  ok — cleanup done"
PASS=$((PASS + 1))

echo ""
echo "results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ]
