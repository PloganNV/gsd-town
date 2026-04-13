#!/usr/bin/env bash
# gastown.sh — GSD/gastown integration helper functions
# Source this file to get detect_gastown() and related helpers.
# All gt commands run from ~/gt (town workspace) to avoid "not in a Gas Town workspace" error.
# bd commands run from ~/gt/gastown/mayor/rig/ to get correct gt-* bead prefix.

set -euo pipefail

GT_BIN="${HOME}/.local/bin/gt"
BD_BIN="${HOME}/go/bin/bd"
GT_TOWN_DIR="${HOME}/gt"
GT_RIG_DIR="${HOME}/gt/gastown/mayor/rig"

# HOOK SYNC SAFETY
# gt hooks sync writes ONLY .claude/settings.json via the hooks package.
# It reads base config + role overrides and merges only the "hooks" key into settings.json.
# CLAUDE.md files are NEVER written by gt hooks sync (confirmed: internal/hooks/merge.go).
#
# GSD integration convention:
#   - All GSD orientation context goes into CLAUDE.md (via generate-claude-md)
#   - All polecat task context goes into bead notes (via format_plan_notes)
#   - NEITHER location is touched by gt hooks sync
#   - If gt hooks sync is removing GSD hooks from settings.json:
#     add the GSD hook to the gastown base config via: gt hooks base (EDITOR opens config)

# detect_gastown()
# Returns "true" if gastown is available and should be used; "false" otherwise.
# Checks (in order):
#   1. workflow.use_gastown config flag — if "false", skip gastown
#   2. gt binary in PATH (or at known absolute path)
#   3. gt daemon status (exit code, must run from town workspace)
# Side effect: none. Safe to call multiple times.
detect_gastown() {
  # Check force-disable flag first
  local use_gastown
  use_gastown=$(node "${HOME}/.claude/get-shit-done/bin/gsd-tools.cjs" config-get workflow.use_gastown 2>/dev/null || echo "true")
  if [ "$use_gastown" = "false" ]; then
    echo "false"
    return 0
  fi

  # Check gt binary availability
  if ! command -v gt >/dev/null 2>&1 && [ ! -x "$GT_BIN" ]; then
    echo "false"
    return 0
  fi

  # Determine gt command (prefer PATH, fallback to absolute)
  local gt_cmd="gt"
  if ! command -v gt >/dev/null 2>&1; then
    gt_cmd="$GT_BIN"
  fi

  # Check daemon running (must run from town workspace)
  if [ ! -d "$GT_TOWN_DIR" ]; then
    echo "false"
    return 0
  fi

  local exit_code=0
  (cd "$GT_TOWN_DIR" && "$gt_cmd" daemon status >/dev/null 2>&1) || exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

# gt_cmd()
# Returns the gt binary path (PATH or absolute fallback).
gt_cmd() {
  if command -v gt >/dev/null 2>&1; then
    echo "gt"
  else
    echo "$GT_BIN"
  fi
}

# bd_cmd()
# Returns the bd binary path (always absolute — bd is not in system PATH).
bd_cmd() {
  echo "$BD_BIN"
}

# create_plan_bead()
# Creates one bead in the gastown rig database for a GSD plan.
# MUST be run from ~/gt/gastown/mayor/rig/ (done internally via cd).
# Uses absolute path for bd — bd is at ~/go/bin/bd, not in system PATH.
#
# Args:
#   $1 — phase number (e.g., "02")
#   $2 — plan number (e.g., "01")
#   $3 — objective (e.g., "Create detection layer")
#   $4 — notes content (multiline markdown; the plan context polecats read at prime time)
#
# Outputs: bead ID (e.g., "gt-abc123") on stdout; errors on stderr.
# Returns: 0 on success, 1 on failure.
create_plan_bead() {
  local phase_num="${1:?phase_num required}"
  local plan_num="${2:?plan_num required}"
  local objective="${3:?objective required}"
  local notes_content="${4:-}"

  local title="Phase ${phase_num} Plan ${plan_num}: ${objective}"

  if [ ! -d "$GT_RIG_DIR" ]; then
    echo "ERROR: rig dir not found: $GT_RIG_DIR" >&2
    return 1
  fi

  local raw_output bead_id
  raw_output=$(cd "$GT_RIG_DIR" && \
    "$BD_BIN" create \
      --title "$title" \
      --notes "$notes_content" \
      --silent \
      2>&1)

  # Filter Dolt connection pool noise (cosmetic — write already succeeded)
  bead_id=$(echo "$raw_output" | grep -v "Warning\|mysql\|timeout\|read tcp" | grep -v "^$" | head -1)

  if [ -z "$bead_id" ]; then
    echo "ERROR: bead creation returned empty ID. Raw output: $raw_output" >&2
    return 1
  fi

  echo "$bead_id"
}

# create_phase_convoy()
# Creates one convoy per GSD phase for tracking all plan beads.
# Runs from ~/gt (town workspace).
#
# Note: gt convoy create requires at least one issue ID at creation time.
# The first_bead_id is added to the convoy at create time, not separately.
#
# Note: gt convoy create does NOT support --json. Convoy ID is parsed from
# text output: the line "✓ Created convoy 🚚 hq-cv-XXXXX" contains the ID.
# gt commands internally call bd — PATH must include ~/go/bin.
#
# Args:
#   $1 — phase number (e.g., "02")
#   $2 — phase name (e.g., "dispatch-bridge")
#   $3 — first bead ID to track in convoy (required by gt convoy create)
#
# Outputs: convoy ID on stdout; errors on stderr.
# Returns: 0 on success, 1 on failure.
create_phase_convoy() {
  local phase_num="${1:?phase_num required}"
  local phase_name="${2:?phase_name required}"
  local first_bead_id="${3:?first_bead_id required}"

  local convoy_title="GSD Phase ${phase_num}: ${phase_name}"

  # gt internally calls bd — bd is not in system PATH so export it
  local result
  result=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin" \
    "$(gt_cmd)" convoy create \
      "$convoy_title" \
      "$first_bead_id" \
      --owned \
      --merge=local \
      2>&1)

  # Parse convoy ID from text output: "✓ Created convoy 🚚 hq-cv-XXXXX"
  # The ID is the last token on that line (hq-cv-* or similar prefix)
  local convoy_id
  convoy_id=$(echo "$result" | grep -o 'hq-[a-z0-9-]*' | head -1)

  if [ -z "$convoy_id" ]; then
    echo "ERROR: convoy creation returned empty ID. Raw output: $result" >&2
    return 1
  fi

  echo "$convoy_id"
}

# add_bead_to_convoy()
# Adds a bead to an existing convoy.
# Runs from ~/gt (town workspace). Fire-and-forget — failure is non-fatal.
#
# Args:
#   $1 — convoy ID
#   $2 — bead ID
add_bead_to_convoy() {
  local convoy_id="${1:?convoy_id required}"
  local bead_id="${2:?bead_id required}"

  # PATH must include ~/go/bin so gt can internally call bd
  (cd "$GT_TOWN_DIR" && PATH="$PATH:${HOME}/go/bin" "$(gt_cmd)" convoy add "$convoy_id" "$bead_id") || true
}

# check_polecat_state()
# Returns the state of the polecat assigned to a bead, or "unknown" if not found.
# Runs from ~/gt (town workspace).
#
# Args:
#   $1 — bead ID (e.g., "gt-abc123")
#
# Outputs: state string ("working", "idle", "done", "stuck", "stalled", "unknown")
check_polecat_state() {
  local bead_id="${1:?bead_id required}"

  local state
  state=$(cd "$GT_TOWN_DIR" && \
    "$(gt_cmd)" polecat list gastown --json 2>/dev/null | \
    python3 -c "
import sys, json
items = json.load(sys.stdin)
bead = sys.argv[1]
match = [i for i in items if i.get('issue') == bead]
print(match[0]['state'] if match else 'unknown')
" "$bead_id" 2>/dev/null || echo "unknown")

  echo "${state:-unknown}"
}

# dispatch_plan_to_polecat()
# Dispatches a GSD plan bead to the gastown rig via gt sling.
# Adds the bead to the phase convoy, then slings to gastown.
# Uses --no-convoy (GSD manages its own convoy) and --no-merge (GSD verification pipeline).
#
# Args:
#   $1 — bead ID (e.g., "gt-abc123")
#   $2 — convoy ID (for add_bead_to_convoy call)
#
# Outputs: status messages on stdout; errors on stderr.
# Returns: 0 on success, 1 on failure (calling code should fall back to Task() spawning).
dispatch_plan_to_polecat() {
  local bead_id="${1:?bead_id required}"
  local convoy_id="${2:?convoy_id required}"

  # Add bead to phase convoy (non-fatal if fails)
  add_bead_to_convoy "$convoy_id" "$bead_id"

  # Dispatch polecat via gt sling
  # --no-convoy: GSD created the convoy; prevent gt sling from creating a second one
  # --no-merge: keep work on feature branch for GSD verification pipeline (not Refinery)
  # PATH must include ~/go/bin (bd) and /opt/homebrew/bin (tmux) for gt sling to succeed
  local sling_output exit_code
  exit_code=0
  sling_output=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
    "$(gt_cmd)" sling "$bead_id" gastown \
      --no-convoy \
      --no-merge \
      2>&1) || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    echo "ERROR: gt sling failed for $bead_id (exit $exit_code): $sling_output" >&2
    return 1
  fi

  echo "Dispatched bead $bead_id to gastown polecat"

  # Allow polecat session startup time before state check
  # Note: polecat naming is auto-assigned by gastown (random words like "Toast")
  sleep 5

  local polecat_state
  polecat_state=$(check_polecat_state "$bead_id")
  echo "Polecat state for $bead_id: ${polecat_state}"

  # "working" = session is live. "unknown" = may still be starting up. Both are acceptable.
  # "stuck" or "stalled" after 5s would be a real problem.
  if [ "$polecat_state" = "stuck" ] || [ "$polecat_state" = "stalled" ]; then
    echo "WARNING: polecat entered $polecat_state state for $bead_id" >&2
  fi

  return 0
}

# format_plan_notes()
# Formats GSD plan content into the bead notes markdown that polecats read at gt prime time.
# The format is designed so a polecat can begin work from notes alone,
# without reading .planning/ itself.
#
# Args:
#   $1 — plan file path (e.g., "/Users/laul_pogan/Source/gastown/.planning/phases/02-dispatch-bridge/02-01-PLAN.md")
#   $2 — phase number (e.g., "02")
#   $3 — plan number (e.g., "01")
#   $4 — objective text (single line summary)
#   $5 — success criteria (multiline; from plan's <success_criteria> section)
#   $6 — task list (multiline; from plan's <tasks> section — task names and actions)
#   $7 — convoy_id (optional; from create_phase_convoy())
#   $8 — bead_id (optional; from create_plan_bead())
#
# Outputs: formatted markdown string for use as bead --notes value
format_plan_notes() {
  local plan_path="${1:?plan_path required}"
  local phase_num="${2:?phase_num required}"
  local plan_num="${3:?plan_num required}"
  local objective="${4:?objective required}"
  local success_criteria="${5:-}"
  local task_list="${6:-}"
  local convoy_id="${7:-}"
  local bead_id="${8:-}"

  # Derive project root from plan path
  local project_dir
  project_dir=$(python3 -c "import os; p='${plan_path}'; idx=p.find('/.planning/'); print(p[:idx] if idx >= 0 else os.path.dirname(p))" 2>/dev/null || echo "")

  cat <<NOTES
# GSD Plan Context

**Phase:** ${phase_num}
**Plan:** ${plan_num}
**Plan file:** ${plan_path}

## Objective

${objective}

## Tasks

${task_list}

## Success Criteria

${success_criteria}

## Instructions

You are a GSD executor polecat. Your job is to execute the tasks listed above.
Read the full plan file at: ${plan_path}
Follow the execute-plan.md workflow from: \$HOME/.claude/get-shit-done/workflows/execute-plan.md

**CRITICAL — Before calling gt done:**
1. Create SUMMARY.md in the plan directory (${plan_path%/*}/)
2. Write SUMMARY.md content to this bead's notes field:
   source \$HOME/.claude/get-shit-done/bin/lib/gastown.sh
   BEAD_ID=\$(gt polecat show --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('issue',''))" 2>/dev/null || echo "")
   if [ -n "\$BEAD_ID" ]; then
     write_results_to_bead "\$BEAD_ID" "\$(cat \${plan_path%/*}/*-SUMMARY.md 2>/dev/null)"
   fi
3. Only call gt done after SUMMARY.md content is in the bead.

## Gastown Context

**Bead ID:** ${bead_id:-"(not yet assigned)"}
**Convoy ID:** ${convoy_id:-"(no convoy)"}
**Town root:** ${GT_TOWN_DIR}
**Rig dir:** ${GT_RIG_DIR}

Source GSD helpers: source \$HOME/.claude/get-shit-done/bin/lib/gastown.sh
Registry (bead<->plan map): ${project_dir}/.planning/gastown.json
NOTES
}

# write_results_to_bead()
# Writes polecat execution results to the bead notes field via bd update.
# Run from ~/gt/gastown/mayor/rig/ for correct bead prefix routing.
#
# Call this BEFORE gt done so results survive worktree teardown.
# The orchestrator calls this when reconstructing SUMMARY.md from bead.
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#   $2 — result_content (multiline markdown — SUMMARY.md content)
#
# Returns: 0 on success, 1 on failure.
write_results_to_bead() {
  local bead_id="${1:?bead_id required}"
  local result_content="${2:?result_content required}"

  if [ ! -d "$GT_RIG_DIR" ]; then
    echo "ERROR: rig dir not found: $GT_RIG_DIR" >&2
    return 1
  fi

  local raw_output exit_code=0
  raw_output=$(cd "$GT_RIG_DIR" && \
    "$BD_BIN" update "$bead_id" \
      --notes "$result_content" \
      2>&1) || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    echo "ERROR: bd update failed for $bead_id (exit $exit_code): $raw_output" >&2
    return 1
  fi

  echo "Results written to bead $bead_id"
  return 0
}

# store_bead_mapping()
# Persists the bead<->plan mapping to .planning/gastown.json.
# Call immediately after create_plan_bead() succeeds.
# Uses python3 (guaranteed present on macOS) for JSON manipulation.
#
# Args:
#   $1 — project_dir: absolute path to GSD project root (where .planning/ lives)
#   $2 — phase_num: e.g., "03"
#   $3 — plan_id: e.g., "03-01"
#   $4 — bead_id: e.g., "gt-abc123"
#   $5 — convoy_id: e.g., "hq-cv-xxxxx" (may be empty for first plan before convoy exists)
#   $6 — objective: single-line plan objective text
#
# Output: writes/updates .planning/gastown.json
# Returns: 0 on success, 1 on failure.
store_bead_mapping() {
  local project_dir="${1:?project_dir required}"
  local phase_num="${2:?phase_num required}"
  local plan_id="${3:?plan_id required}"
  local bead_id="${4:?bead_id required}"
  local convoy_id="${5:-}"
  local objective="${6:-}"

  local registry_path="${project_dir}/.planning/gastown.json"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  python3 - "$registry_path" "$phase_num" "$plan_id" "$bead_id" "$convoy_id" "$objective" "$timestamp" <<'PYEOF'
import sys, json, os

registry_path, phase_num, plan_id, bead_id, convoy_id, objective, timestamp = sys.argv[1:]

# Load existing registry or initialize
if os.path.exists(registry_path):
    with open(registry_path) as f:
        registry = json.load(f)
else:
    registry = {"version": 1, "phases": {}}

# Ensure phase key exists
if phase_num not in registry["phases"]:
    registry["phases"][phase_num] = {"convoy_id": "", "plans": {}}

# Update convoy_id if provided
if convoy_id:
    registry["phases"][phase_num]["convoy_id"] = convoy_id

# Store plan mapping
registry["phases"][phase_num]["plans"][plan_id] = {
    "bead_id": bead_id,
    "objective": objective,
    "dispatched_at": timestamp
}

with open(registry_path, "w") as f:
    json.dump(registry, f, indent=2)
    f.write("\n")

print(f"Stored mapping: {plan_id} -> {bead_id}")
PYEOF
}

# resolve_plan_from_bead()
# Looks up the phase_dir and plan_id for a given bead_id in .planning/gastown.json.
#
# Args:
#   $1 - bead_id (e.g., "gt-abc123")
#   $2 - project_dir (absolute path to project root where .planning/ lives)
#
# Outputs: "phase_dir plan_id" (space-separated) on stdout if found; empty string if not found.
# Returns: 0 always (caller checks for empty output).
resolve_plan_from_bead() {
  local bead_id="${1:?bead_id required}"
  local project_dir="${2:?project_dir required}"

  local registry_path="${project_dir}/.planning/gastown.json"
  if [ ! -f "$registry_path" ]; then
    echo ""
    return 0
  fi

  python3 - "$registry_path" "$bead_id" "$project_dir" <<'PYEOF'
import sys, json, os

registry_path, bead_id, project_dir = sys.argv[1:]

try:
    with open(registry_path) as f:
        registry = json.load(f)
except Exception:
    print("")
    sys.exit(0)

for phase_num, phase_data in registry.get("phases", {}).items():
    for plan_id, plan_data in phase_data.get("plans", {}).items():
        if plan_data.get("bead_id") == bead_id:
            # Derive phase_dir from project_dir and phase number
            # Phase dirs match pattern: .planning/phases/NN-*
            planning_dir = os.path.join(project_dir, ".planning", "phases")
            phase_dir = ""
            if os.path.isdir(planning_dir):
                for entry in os.listdir(planning_dir):
                    if entry.startswith(phase_num + "-"):
                        phase_dir = os.path.join(planning_dir, entry)
                        break
            if not phase_dir:
                # Fallback: construct from phase_num only
                phase_dir = os.path.join(planning_dir, phase_num)
            print(f"{phase_dir} {plan_id}")
            sys.exit(0)

print("")
PYEOF
}

# check_escalation_status()
# Checks whether a bead has been flagged as escalated (polecat called gt escalate).
# Reads bd show --json and checks for escalated bool field or state == "escalated".
#
# Args:
#   $1 - bead_id (e.g., "gt-abc123")
#
# Outputs: "yes" if escalated, "no" otherwise.
check_escalation_status() {
  local bead_id="${1:?bead_id required}"

  local result
  result=$(cd "$GT_RIG_DIR" && \
    "$BD_BIN" show "$bead_id" --json 2>/dev/null | \
    python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Check for escalated boolean or state == 'escalated'
    if d.get('escalated') or d.get('state') == 'escalated':
        print('yes')
    else:
        print('no')
except:
    print('no')
" 2>/dev/null || echo "no")

  echo "${result:-no}"
}

# reconstruct_summary_from_bead()
# Reads polecat execution results from bead notes and writes SUMMARY.md
# to the GSD phase plan directory.
#
# Args:
#   $1 - bead_id (e.g., "gt-abc123")
#   $2 - phase_dir (absolute path to phase directory)
#   $3 - plan_id (e.g., "03-01")
#
# Returns: 0 on success (SUMMARY.md written), 1 on failure.
reconstruct_summary_from_bead() {
  local bead_id="${1:?bead_id required}"
  local phase_dir="${2:?phase_dir required}"
  local plan_id="${3:?plan_id required}"

  local summary_path="${phase_dir}/${plan_id}-SUMMARY.md"

  if [ ! -d "$GT_RIG_DIR" ]; then
    echo "ERROR: rig dir not found: $GT_RIG_DIR" >&2
    return 1
  fi

  local bead_json notes_content
  bead_json=$(cd "$GT_RIG_DIR" && \
    "$BD_BIN" show "$bead_id" --json 2>&1) || {
    echo "ERROR: bd show failed for $bead_id" >&2
    return 1
  }

  notes_content=$(echo "$bead_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    notes = data.get('notes', '')
    print(notes)
except Exception as e:
    sys.stderr.write(f'ERROR: JSON parse failed: {e}\n')
    sys.exit(1)
" 2>&1) || {
    echo "ERROR: failed to parse bead JSON for $bead_id" >&2
    return 1
  }

  if [ -z "$notes_content" ]; then
    echo "WARNING: bead $bead_id has empty notes — polecat may not have written results" >&2
    printf 'phase: %s\nplan: %s\n\n# %s SUMMARY (reconstructed from bead)\n\n**Status:** Notes empty\n**Bead:** %s\n\n## Self-Check: FAILED\n\nPolecat completed but notes field is empty. Manual review required.\n' \
      "$(basename "$phase_dir")" "$plan_id" "$plan_id" "$bead_id" > "$summary_path"
    return 1
  fi

  echo "$notes_content" > "$summary_path"
  echo "SUMMARY.md reconstructed from bead $bead_id -> $summary_path"
  return 0
}

# wait_for_polecats()
# Polls polecat state for all beads in a wave until all reach terminal state.
# Terminal states: done (success), stuck/stalled/timeout (failure).
#
# Args:
#   $1 - bead_ids: space-separated list of bead IDs to watch
#   $2 - poll_interval: seconds between polls (default: 30)
#   $3 - timeout_seconds: max wait time in seconds (default: 1800 = 30min)
#
# Outputs per-bead completion: "RESULT:BEAD_ID:STATE" on stdout
# Returns: 0 if ALL beads reached "done", 1 if any failed or timed out.
wait_for_polecats() {
  local bead_ids_str="${1:?bead_ids required}"
  local poll_interval="${2:-30}"
  local timeout_seconds="${3:-1800}"

  local bead_ids=()
  read -ra bead_ids <<< "$bead_ids_str"

  local start_time
  start_time=$(date +%s)
  local pending=("${bead_ids[@]}")
  declare -A final_states

  while [ "${#pending[@]}" -gt 0 ]; do
    local elapsed=$(( $(date +%s) - start_time ))

    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      echo "TIMEOUT: waited ${elapsed}s — marking remaining polecats as failed" >&2
      for bead_id in "${pending[@]}"; do
        final_states["$bead_id"]="timeout"
        echo "RESULT:${bead_id}:timeout"
        # Write failure SUMMARY.md so GSD verification pipeline has an artifact
        local resolved
        resolved=$(resolve_plan_from_bead "$bead_id" "${PROJECT_DIR:-$(pwd)}")
        if [ -n "$resolved" ]; then
          local fail_phase_dir fail_plan_id
          read -r fail_phase_dir fail_plan_id <<< "$resolved"
          reconstruct_summary_from_bead "$bead_id" "$fail_phase_dir" "$fail_plan_id" || true
        fi
      done
      return 1
    fi

    local polecat_json
    polecat_json=$(cd "$GT_TOWN_DIR" && \
      PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
      "$(gt_cmd)" polecat list gastown --json 2>/dev/null || echo "[]")

    local still_pending=()
    for bead_id in "${pending[@]}"; do
      local state
      state=$(echo "$polecat_json" | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    bead = sys.argv[1]
    match = [i for i in items if i.get('issue') == bead]
    print(match[0]['state'] if match else 'unknown')
except:
    print('unknown')
" "$bead_id" 2>/dev/null || echo "unknown")

      echo "POLLING: ${bead_id} state=${state} (elapsed ${elapsed}s)"

      # RESIL-02: Check escalation BEFORE state case — catches escalated beads
      # regardless of their Witness state (they may still show as working/idle).
      local escalated
      escalated=$(check_escalation_status "$bead_id")
      if [ "$escalated" = "yes" ]; then
        final_states["$bead_id"]="escalated"
        echo "RESULT:${bead_id}:escalated"
        echo "ESCALATION: polecat for $bead_id called gt escalate — human decision required" >&2
        continue
      fi

      case "$state" in
        done)
          final_states["$bead_id"]="done"
          echo "RESULT:${bead_id}:done"
          ;;
        stuck|stalled)
          final_states["$bead_id"]="$state"
          echo "RESULT:${bead_id}:${state}"
          echo "ERROR: polecat for $bead_id entered $state state" >&2
          # RESIL-01: Write failure SUMMARY.md so GSD verification pipeline has an artifact
          local resolved
          resolved=$(resolve_plan_from_bead "$bead_id" "${PROJECT_DIR:-$(pwd)}")
          if [ -n "$resolved" ]; then
            local fail_phase_dir fail_plan_id
            read -r fail_phase_dir fail_plan_id <<< "$resolved"
            reconstruct_summary_from_bead "$bead_id" "$fail_phase_dir" "$fail_plan_id" || true
          fi
          ;;
        unknown)
          # Polecat not in list — may have completed and been torn down
          # Check bead notes: notes present = polecat wrote results before gt done
          local bead_has_notes
          bead_has_notes=$(cd "$GT_RIG_DIR" && \
            "$BD_BIN" show "$bead_id" --json 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if d.get('notes','').strip() else 'no')" \
            2>/dev/null || echo "no")
          if [ "$bead_has_notes" = "yes" ]; then
            final_states["$bead_id"]="done"
            echo "RESULT:${bead_id}:done"
            echo "NOTE: polecat for $bead_id not in list but bead has notes — treating as done"
          else
            still_pending+=("$bead_id")
          fi
          ;;
        *)
          still_pending+=("$bead_id")
          ;;
      esac
    done

    pending=("${still_pending[@]}")

    if [ "${#pending[@]}" -gt 0 ]; then
      sleep "$poll_interval"
    fi
  done

  local any_failed=0
  for bead_id in "${!final_states[@]}"; do
    case "${final_states[$bead_id]}" in
      done) ;;
      *) any_failed=1 ;;
    esac
  done

  return "$any_failed"
}
