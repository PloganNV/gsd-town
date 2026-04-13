#!/usr/bin/env bash
# bead-state.sh — Bead-backed state management for GSD
#
# Provides four public functions:
#   generate_state_from_beads(project_dir)        — regenerate STATE.md from bead data
#   read_plan_result_from_bead(bead_id)           — read SUMMARY-equivalent content from bead
#   check_phase_completion_from_convoy(convoy_id) — query convoy/bead aggregate completion
#   sync_requirements_from_beads(project_dir)     — update REQUIREMENTS.md from bead status
#
# BEADS-01: Beads are source of truth for work status; STATE.md is a generated view
# BEADS-02: GSD verifier reads polecat results directly from beads (no SUMMARY.md round-trip)
# BEADS-03: Phase completion derived from convoy status (all beads closed = phase done)
#
# Usage:
#   source "$HOME/.claude/get-shit-done/bin/lib/bead-state.sh"
#   generate_state_from_beads "/path/to/project"
#
# Research basis: .planning/phases/07-10-RESEARCH.md (Phase 9 section)
#   - Agent state lives in bead `description` field, NOT a structured column
#   - `bd list --json` requires `--flat` flag for actual JSON output
#   - `bd show --json` returns an array — always jq '.[0]' (handled via python3 below)
#   - Convoy status derives from bead status; GSD must aggregate children counts explicitly
#   - bd is at ~/go/bin/bd — not in system PATH; must run from rig dir for correct prefix routing

set -euo pipefail

# Path constants (shared with gastown.sh — keep in sync)
_BS_BD_BIN="${HOME}/go/bin/bd"
_BS_GT_BIN="${HOME}/.local/bin/gt"
_BS_GT_TOWN_DIR="${HOME}/gt"
_BS_GT_RIG_DIR="${HOME}/gt/gastown/mayor/rig"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _bs_bd_show(bead_id)
# Runs bd show --json from rig dir. Returns parsed JSON object on stdout.
# bd show returns an array; we always take element [0].
_bs_bd_show() {
  local bead_id="${1:?bead_id required}"

  if [ ! -d "$_BS_GT_RIG_DIR" ]; then
    echo "ERROR: rig dir not found: $_BS_GT_RIG_DIR" >&2
    return 1
  fi

  cd "$_BS_GT_RIG_DIR" && \
    "$_BS_BD_BIN" show "$bead_id" --json 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # bd show returns an array — always take element [0]
    if isinstance(data, list):
        data = data[0] if data else {}
    print(json.dumps(data))
except Exception as e:
    sys.stderr.write(f'ERROR: failed to parse bead JSON: {e}\n')
    sys.exit(1)
" 2>/dev/null || echo "{}"
}

# _bs_bd_list(extra_args...)
# Runs bd list --json --flat from rig dir with any extra filter args.
# Returns one JSON object per line (NDJSON), or empty string.
_bs_bd_list() {
  local extra_args=("$@")

  if [ ! -d "$_BS_GT_RIG_DIR" ]; then
    echo "ERROR: rig dir not found: $_BS_GT_RIG_DIR" >&2
    return 1
  fi

  local raw
  raw=$(cd "$_BS_GT_RIG_DIR" && \
    "$_BS_BD_BIN" list --json --flat "${extra_args[@]}" 2>/dev/null || echo "")

  # Handle "No issues found." text output (bd v0.59+ may return this instead of empty JSON)
  if echo "$raw" | grep -q "^No issues found"; then
    echo ""
    return 0
  fi

  echo "$raw"
}

# _bs_load_registry(project_dir)
# Reads .planning/gastown.json and outputs its content.
# Returns empty object if file missing.
_bs_load_registry() {
  local project_dir="${1:?project_dir required}"
  local registry_path="${project_dir}/.planning/gastown.json"

  if [ ! -f "$registry_path" ]; then
    echo "{}"
    return 0
  fi

  cat "$registry_path"
}

# ---------------------------------------------------------------------------
# generate_state_from_beads(project_dir)
# ---------------------------------------------------------------------------
# BEADS-01 implementation.
# Reads gastown.json to discover all registered bead IDs, queries each bead
# via bd show --json --flat, and regenerates STATE.md from the live bead data.
#
# Args:
#   $1 — project_dir: absolute path to GSD project root (where .planning/ lives)
#
# Outputs: writes .planning/STATE.md
# Returns: 0 on success, 1 on failure.
generate_state_from_beads() {
  local project_dir="${1:?project_dir required}"
  local state_path="${project_dir}/.planning/STATE.md"
  local registry_path="${project_dir}/.planning/gastown.json"

  if [ ! -f "$registry_path" ]; then
    echo "WARN: gastown.json not found at $registry_path — STATE.md not regenerated" >&2
    return 0
  fi

  # Collect per-phase bead summaries
  local state_body
  state_body=$(python3 - "$registry_path" "$_BS_BD_BIN" "$_BS_GT_RIG_DIR" <<'PYEOF'
import sys, json, subprocess, os

registry_path, bd_bin, rig_dir = sys.argv[1:]

try:
    with open(registry_path) as f:
        registry = json.load(f)
except Exception as e:
    print(f"ERROR: could not load registry: {e}", file=sys.stderr)
    sys.exit(1)

phases_data = registry.get("phases", {})
if not phases_data:
    print("No phases registered in gastown.json.")
    sys.exit(0)

lines = []
total_plans = 0
completed_plans = 0

for phase_num in sorted(phases_data.keys()):
    phase_info = phases_data[phase_num]
    convoy_id = phase_info.get("convoy_id", "")
    plans = phase_info.get("plans", {})

    lines.append(f"\n### Phase {phase_num}")
    if convoy_id:
        lines.append(f"Convoy: `{convoy_id}`")

    for plan_id in sorted(plans.keys()):
        plan_info = plans[plan_id]
        bead_id = plan_info.get("bead_id", "")
        objective = plan_info.get("objective", "")
        dispatched_at = plan_info.get("dispatched_at", "")
        total_plans += 1

        if not bead_id:
            lines.append(f"- `{plan_id}`: NO BEAD ID (registry error)")
            continue

        # Query bead from bd show --json (must run from rig_dir)
        try:
            raw = subprocess.check_output(
                [bd_bin, "show", bead_id, "--json"],
                cwd=rig_dir,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
            data = json.loads(raw)
            if isinstance(data, list):
                data = data[0] if data else {}
        except Exception as e:
            lines.append(f"- `{plan_id}` `{bead_id}`: QUERY FAILED ({e})")
            continue

        status = data.get("status", "unknown")
        title = data.get("title", objective)
        updated_at = data.get("updated_at", dispatched_at)
        agent_state = data.get("agent_state", "")
        notes_present = bool(data.get("notes", "").strip())

        if status == "closed":
            completed_plans += 1
            state_icon = "[done]"
        elif status in ("in_progress", "open"):
            state_icon = "[running]" if agent_state in ("working", "spawning") else "[open]"
        else:
            state_icon = f"[{status}]"

        notes_flag = " (results in bead)" if notes_present else ""
        lines.append(
            f"- `{plan_id}` `{bead_id}` {state_icon}: {objective or title}{notes_flag}"
        )
        if agent_state:
            lines.append(f"  agent_state: {agent_state} | updated: {updated_at}")

print(f"total_plans={total_plans}")
print(f"completed_plans={completed_plans}")
print("---BODY---")
print("\n".join(lines))
PYEOF
  )

  # Parse totals and body from python output
  local total_plans completed_plans bead_body
  total_plans=$(echo "$state_body" | grep "^total_plans=" | cut -d= -f2)
  completed_plans=$(echo "$state_body" | grep "^completed_plans=" | cut -d= -f2)
  bead_body=$(echo "$state_body" | sed -n '/^---BODY---$/,$ p' | tail -n +2)

  total_plans="${total_plans:-0}"
  completed_plans="${completed_plans:-0}"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read existing STATE.md frontmatter so we preserve metadata
  local existing_frontmatter=""
  if [ -f "$state_path" ]; then
    existing_frontmatter=$(python3 -c "
import sys
content = open(sys.argv[1]).read()
# Extract YAML frontmatter between first two '---' lines
parts = content.split('---')
if len(parts) >= 3:
    print(parts[1].strip())
" "$state_path" 2>/dev/null || echo "")
  fi

  cat > "$state_path" <<STATE_MD
---
gsd_state_version: 1.0
generated_from: beads
last_updated: "${timestamp}"
total_plans: ${total_plans}
completed_plans: ${completed_plans}
---

# Project State (Generated from Beads)

> This file is a **generated view**. Source of truth is the bead database.
> Regenerate with: \`generate_state_from_beads <project_dir>\`
> (BEADS-01: Beads are source of truth for work status)

## Bead Status by Phase
${bead_body}

## Registry

Source: \`.planning/gastown.json\`
Generated: ${timestamp}
STATE_MD

  echo "STATE.md regenerated from beads -> $state_path ($completed_plans/$total_plans plans complete)"
  return 0
}

# ---------------------------------------------------------------------------
# read_plan_result_from_bead(bead_id)
# ---------------------------------------------------------------------------
# BEADS-02 implementation.
# Reads the bead's notes field and returns structured content that the GSD
# verifier can consume — same format as SUMMARY.md content.
# The verifier can call this instead of reading SUMMARY.md from disk.
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#
# Outputs: SUMMARY.md-equivalent markdown content on stdout.
# Returns:
#   0 — content found and printed
#   1 — bead not found or notes empty
read_plan_result_from_bead() {
  local bead_id="${1:?bead_id required}"

  local bead_json
  bead_json=$(_bs_bd_show "$bead_id") || {
    echo "ERROR: could not query bead $bead_id" >&2
    return 1
  }

  local notes
  notes=$(echo "$bead_json" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    notes = data.get('notes', '').strip()
    if notes:
        print(notes)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null) || {
    echo "WARN: bead $bead_id has no notes content — polecat may not have written results yet" >&2
    return 1
  }

  # Emit the notes as the plan result (BEADS-02: no SUMMARY.md round-trip)
  echo "$notes"
  return 0
}

# ---------------------------------------------------------------------------
# check_phase_completion_from_convoy(convoy_id)
# ---------------------------------------------------------------------------
# BEADS-03 implementation.
# Queries the convoy bead and all its child beads to determine phase completion.
# Does NOT rely on convoy auto-propagation (not guaranteed by gastown source).
#
# Research finding: Convoy status does NOT auto-update — GSD must count children.
# [VERIFIED: gastown/internal/convoy/operations.go]
#
# Args:
#   $1 — convoy_id (e.g., "hq-cv-xxxxx")
#
# Outputs: "complete" | "in-progress" | "failed" on stdout
# Side effect: prints per-child status lines to stderr for diagnostics
# Returns: 0 always (caller checks stdout value)
check_phase_completion_from_convoy() {
  local convoy_id="${1:?convoy_id required}"

  local convoy_json
  convoy_json=$(_bs_bd_show "$convoy_id") || {
    echo "failed"
    return 0
  }

  # Extract children list from convoy bead
  local children_json child_count
  children_json=$(echo "$convoy_json" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    children = data.get('children', [])
    print(json.dumps(children))
except Exception:
    print('[]')
")
  child_count=$(echo "$children_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [ "$child_count" -eq 0 ]; then
    # No children recorded — convoy exists but no work beads added yet
    echo "in-progress"
    return 0
  fi

  # Count closed vs open children by querying each bead
  local closed_count=0
  local failed_count=0
  local open_count=0

  while IFS= read -r child_id; do
    [ -z "$child_id" ] && continue

    local child_json child_status agent_state
    child_json=$(_bs_bd_show "$child_id" 2>/dev/null) || child_json="{}"
    child_status=$(echo "$child_json" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
print(d.get('status', 'unknown'))
" 2>/dev/null || echo "unknown")
    agent_state=$(echo "$child_json" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
print(d.get('agent_state', ''))
" 2>/dev/null || echo "")

    echo "CHILD: ${child_id} status=${child_status} agent_state=${agent_state}" >&2

    case "$child_status" in
      closed)
        closed_count=$(( closed_count + 1 ))
        ;;
      tombstone|stuck)
        failed_count=$(( failed_count + 1 ))
        ;;
      *)
        open_count=$(( open_count + 1 ))
        ;;
    esac
  done < <(echo "$children_json" | python3 -c "
import sys, json
children = json.load(sys.stdin)
for c in children:
    print(c)
")

  echo "CONVOY: ${convoy_id} children=${child_count} closed=${closed_count} open=${open_count} failed=${failed_count}" >&2

  if [ "$failed_count" -gt 0 ] && [ "$open_count" -eq 0 ] && [ "$closed_count" -lt "$child_count" ]; then
    echo "failed"
  elif [ "$closed_count" -eq "$child_count" ] && [ "$child_count" -gt 0 ]; then
    # BEADS-03: all beads closed = phase done
    echo "complete"
  else
    echo "in-progress"
  fi
}

# ---------------------------------------------------------------------------
# sync_requirements_from_beads(project_dir)
# ---------------------------------------------------------------------------
# Updates REQUIREMENTS.md traceability table based on bead completion status.
# Maps bead IDs back to requirement IDs via gastown.json, then marks requirements
# complete if their associated plan bead is closed.
#
# Args:
#   $1 — project_dir: absolute path to GSD project root
#
# Outputs: status messages on stdout
# Returns: 0 on success, 1 on failure.
sync_requirements_from_beads() {
  local project_dir="${1:?project_dir required}"
  local registry_path="${project_dir}/.planning/gastown.json"
  local requirements_path="${project_dir}/.planning/REQUIREMENTS.md"

  if [ ! -f "$registry_path" ]; then
    echo "WARN: gastown.json not found — requirements sync skipped" >&2
    return 0
  fi

  if [ ! -f "$requirements_path" ]; then
    echo "WARN: REQUIREMENTS.md not found — requirements sync skipped" >&2
    return 0
  fi

  # Build a map of plan_id -> bead_id -> status from beads
  local completed_plans
  completed_plans=$(python3 - "$registry_path" "$_BS_BD_BIN" "$_BS_GT_RIG_DIR" <<'PYEOF'
import sys, json, subprocess

registry_path, bd_bin, rig_dir = sys.argv[1:]

try:
    with open(registry_path) as f:
        registry = json.load(f)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

completed = []
for phase_num, phase_info in registry.get("phases", {}).items():
    for plan_id, plan_info in phase_info.get("plans", {}).items():
        bead_id = plan_info.get("bead_id", "")
        if not bead_id:
            continue
        try:
            raw = subprocess.check_output(
                [bd_bin, "show", bead_id, "--json"],
                cwd=rig_dir,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
            data = json.loads(raw)
            if isinstance(data, list):
                data = data[0] if data else {}
            if data.get("status") == "closed":
                completed.append(plan_id)
        except Exception:
            continue

print("\n".join(completed))
PYEOF
  )

  if [ -z "$completed_plans" ]; then
    echo "No completed bead plans found — REQUIREMENTS.md unchanged"
    return 0
  fi

  # For each completed plan_id, mark matching requirement checkboxes as done.
  # Requirements typically reference plans in their description or traceability table.
  # We look for lines with the plan_id (e.g., "09-01") and mark checkboxes [ ] -> [x].
  local updated_count=0
  while IFS= read -r plan_id; do
    [ -z "$plan_id" ] && continue

    # Check if REQUIREMENTS.md has any reference to this plan
    if grep -q "$plan_id" "$requirements_path" 2>/dev/null; then
      # Mark checkboxes on lines containing this plan_id as complete
      python3 - "$requirements_path" "$plan_id" <<'PYEOF'
import sys, re

req_path, plan_id = sys.argv[1:]

with open(req_path) as f:
    content = f.read()

# Match lines containing plan_id that have an unchecked checkbox
# Pattern: "- [ ] ... plan_id ..." or "| ... plan_id ... | ... [ ] ..."
updated = []
lines = content.splitlines(keepends=True)
changed = False
for line in lines:
    if plan_id in line and "[ ]" in line:
        line = line.replace("[ ]", "[x]", 1)
        changed = True
    updated.append(line)

if changed:
    with open(req_path, "w") as f:
        f.writelines(updated)
    print(f"Marked requirements complete for plan {plan_id}")
else:
    print(f"No unchecked requirements found for plan {plan_id}")
PYEOF
      updated_count=$(( updated_count + 1 ))
    fi
  done <<< "$completed_plans"

  echo "Requirements sync complete: $updated_count plan(s) processed"
  return 0
}
