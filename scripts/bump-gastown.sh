#!/usr/bin/env bash
# Safely bump the vendor/gastown submodule to a new commit or branch ref.
#
# Usage:
#   bash scripts/bump-gastown.sh <commit-sha-or-branch>
#
# What it does:
#   1. Records the current gt --help output (old baseline)
#   2. Checks out the requested ref in vendor/gastown
#   3. Builds the new gt binary
#   4. Runs test/drift/01-api-surface.sh to verify API surface
#   5. Shows a diff of gt --help output (old vs new) so you can spot changes
#   6. Does NOT commit — review the diff and commit manually if satisfied
#
# Examples:
#   bash scripts/bump-gastown.sh 63bf531f285159edfe207dcedab1962d93a357b6
#   bash scripts/bump-gastown.sh origin/main
#   bash scripts/bump-gastown.sh v1.1.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/gastown"
DRIFT_TEST="$REPO_ROOT/test/drift/01-api-surface.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---- arg check -------------------------------------------------------------

if [ $# -eq 0 ]; then
  echo "Usage: bash scripts/bump-gastown.sh <commit-sha-or-branch>"
  echo ""
  echo "Examples:"
  echo "  bash scripts/bump-gastown.sh 63bf531f285159edfe207dcedab1962d93a357b6"
  echo "  bash scripts/bump-gastown.sh origin/main"
  echo "  bash scripts/bump-gastown.sh v1.1.0"
  exit 1
fi

TARGET_REF="$1"

# ---- record old baseline ---------------------------------------------------

OLD_SHA=$(git -C "$VENDOR_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
OLD_HELP_FILE="$TMP_DIR/help-old.txt"

echo "bump-gastown: current → $OLD_SHA"

if [ -f "$VENDOR_DIR/gt" ]; then
  echo "  recording current gt --help output..."
  "$VENDOR_DIR/gt" --help >"$OLD_HELP_FILE" 2>&1 || true
else
  # Try building current first so we have a baseline
  echo "  no existing gt binary — building current version for baseline..."
  (cd "$VENDOR_DIR" && SKIP_UPDATE_CHECK=1 make build >/dev/null 2>&1) || true
  if [ -f "$VENDOR_DIR/gt" ]; then
    "$VENDOR_DIR/gt" --help >"$OLD_HELP_FILE" 2>&1 || true
  else
    echo "  (no baseline available — skipping diff)"
    touch "$OLD_HELP_FILE"
  fi
fi

# ---- fetch and checkout new ref --------------------------------------------

echo ""
echo "bump-gastown: fetching $TARGET_REF..."
git -C "$VENDOR_DIR" fetch --quiet origin 2>/dev/null || git -C "$VENDOR_DIR" fetch --quiet 2>/dev/null || {
  echo "WARNING: git fetch failed — attempting checkout without fetch"
}

git -C "$VENDOR_DIR" checkout --quiet "$TARGET_REF"
NEW_SHA=$(git -C "$VENDOR_DIR" rev-parse HEAD)
echo "bump-gastown: checked out → $NEW_SHA"

if [ "$OLD_SHA" = "$NEW_SHA" ]; then
  echo "WARNING: new SHA equals old SHA — nothing changed"
fi

# ---- build new gt ----------------------------------------------------------

echo ""
echo "bump-gastown: building gt from $NEW_SHA..."
(cd "$VENDOR_DIR" && SKIP_UPDATE_CHECK=1 make build)
echo "bump-gastown: build complete"

# ---- run drift check -------------------------------------------------------

echo ""
echo "bump-gastown: running API surface drift check..."
if GT_BIN="$VENDOR_DIR/gt" bash "$DRIFT_TEST"; then
  DRIFT_OK=true
  echo ""
  echo "bump-gastown: drift check PASSED — API surface intact"
else
  DRIFT_OK=false
  echo ""
  echo "bump-gastown: drift check FAILED — API surface has changed (see above)"
fi

# ---- show help diff --------------------------------------------------------

NEW_HELP_FILE="$TMP_DIR/help-new.txt"
"$VENDOR_DIR/gt" --help >"$NEW_HELP_FILE" 2>&1 || true

echo ""
echo "── gt --help diff (old: ${OLD_SHA:0:8}  →  new: ${NEW_SHA:0:8}) ──────────────"
if diff --color=always "$OLD_HELP_FILE" "$NEW_HELP_FILE"; then
  echo "(no changes in top-level help output)"
fi
echo "────────────────────────────────────────────────────────────────────────────"

# ---- summary and next steps ------------------------------------------------

echo ""
echo "Summary:"
echo "  old: $OLD_SHA"
echo "  new: $NEW_SHA"
echo "  drift check: $([ "$DRIFT_OK" = true ] && echo "PASSED" || echo "FAILED")"
echo ""

if [ "$DRIFT_OK" = true ]; then
  echo "Next steps (if satisfied with the diff above):"
  echo "  git add vendor/gastown"
  echo "  git commit -m \"chore: bump gastown to ${NEW_SHA:0:12}\""
else
  echo "Drift detected. Options:"
  echo "  1. Update lib/gastown.sh to match the new API, then re-run this script"
  echo "  2. Roll back: cd vendor/gastown && git checkout $OLD_SHA"
  echo ""
  echo "Roll back command:"
  echo "  cd vendor/gastown && git checkout $OLD_SHA"
  exit 1
fi
