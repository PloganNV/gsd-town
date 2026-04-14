#!/usr/bin/env bash
# gastown.sh — GSD/gastown integration helper functions
# Source this file to get detect_gastown() and related helpers.
# All gt commands run from ~/gt (town workspace) to avoid "not in a Gas Town workspace" error.
# bd commands run from ~/gt/gastown/mayor/rig/ to get correct gt-* bead prefix.

set -euo pipefail

GT_BIN="${HOME}/.local/bin/gt"
BD_BIN="${HOME}/go/bin/bd"
# Prefer GSD-Town managed location, fall back to legacy ~/gt
if [ -d "${HOME}/.gsd-town/gastown" ]; then
  GT_TOWN_DIR="${HOME}/.gsd-town"
elif [ -d "${HOME}/gt/gastown" ]; then
  GT_TOWN_DIR="${HOME}/gt"
else
  GT_TOWN_DIR="${HOME}/.gsd-town"
fi
GT_RIG_DIR="${GT_TOWN_DIR}/gastown/mayor/rig"

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

# check_capacity()
# Checks whether the gastown scheduler is at its max_polecats limit.
# Reads scheduler.max_polecats from gt config; if unset/non-numeric, treats as unlimited.
# Counts active polecats (state not in done/stuck/stalled) against the limit.
#
# Outputs: "ok" if capacity available, "full" if at or over limit.
# Returns: 0 always.
check_capacity() {
  # Read scheduler.max_polecats from gastown config
  local max_polecats
  max_polecats=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin" \
    "$(gt_cmd)" config get scheduler.max_polecats 2>/dev/null | tr -d '[:space:]')

  # If config returns empty or non-numeric, treat as unlimited (T-04-01 mitigation)
  if [ -z "$max_polecats" ] || ! echo "$max_polecats" | grep -qE '^[0-9]+$'; then
    echo "ok"
    return 0
  fi

  # Count active polecats (working + idle states, not done/stuck/stalled)
  local active_count
  active_count=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
    "$(gt_cmd)" polecat list gastown --json 2>/dev/null | \
    python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    active = [i for i in items if i.get('state') not in ('done', 'stuck', 'stalled')]
    print(len(active))
except:
    print(0)
" 2>/dev/null || echo "0")

  if [ "$active_count" -ge "$max_polecats" ]; then
    echo "full"
  else
    echo "ok"
  fi
}

# queue_or_dispatch()
# Capacity-governed dispatch wrapper. Polls check_capacity() before calling
# dispatch_plan_to_polecat(). Queues the dispatch (retries every poll_interval)
# until capacity opens or max_wait is exceeded (T-04-02 mitigation).
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#   $2 — convoy_id (e.g., "hq-cv-xxxxx")
#   $3 — poll_interval: seconds between capacity checks (default: 30)
#   $4 — max_wait: max seconds to wait for capacity (default: 900 = 15min)
#
# Outputs: status messages on stdout; errors on stderr.
# Returns: 0 on successful dispatch, 1 on timeout or dispatch failure.
queue_or_dispatch() {
  local bead_id="${1:?bead_id required}"
  local convoy_id="${2:?convoy_id required}"
  local poll_interval="${3:-30}"
  local max_wait="${4:-900}"  # 15 min queue timeout

  local start_time
  start_time=$(date +%s)

  while true; do
    local capacity
    capacity=$(check_capacity)
    if [ "$capacity" = "ok" ]; then
      dispatch_plan_to_polecat "$bead_id" "$convoy_id"
      return $?
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    if [ "$elapsed" -ge "$max_wait" ]; then
      echo "ERROR: queue_or_dispatch timed out after ${elapsed}s waiting for capacity for $bead_id" >&2
      return 1
    fi

    echo "CAPACITY: at max_polecats limit — $bead_id queued (waited ${elapsed}s, retry in ${poll_interval}s)"
    sleep "$poll_interval"
  done
}

# dispatch_plan_to_polecat()
# Dispatches a GSD plan bead to the gastown rig via gt sling.
# Adds the bead to the phase convoy, then slings to gastown.
# Uses --no-convoy (GSD manages its own convoy) and --no-merge (GSD verification pipeline).
#
# Prefer queue_or_dispatch() over calling this directly — queue_or_dispatch()
# enforces scheduler.max_polecats before dispatching.
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

# seance_context_block()
# Queries gt seance for prior session events on a bead and returns a formatted
# markdown section instructing the polecat to recover prior context.
# Returns empty string if no prior events exist (first dispatch).
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#
# Outputs: markdown section string (may be empty) on stdout.
seance_context_block() {
  local bead_id="${1:?bead_id required}"

  # gt seance queries the Seance daemon for prior events on this bead
  # Returns JSON array of prior session events
  local seance_output
  seance_output=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
    "$(gt_cmd)" seance "$bead_id" --json 2>/dev/null || echo "[]")

  local event_count
  event_count=$(echo "$seance_output" | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    print(len(items))
except:
    print(0)
" 2>/dev/null || echo "0")

  if [ "$event_count" -eq 0 ]; then
    echo ""
    return 0
  fi

  # Return Seance context instructions for the polecat
  # Use a sufficiently unique delimiter to avoid collisions with event content (T-04-03 mitigation)
  cat <<GSD_SEANCE_BLOCK

## Prior Session Context (Seance)

This bead has ${event_count} prior session event(s). You are resuming interrupted work.

**To recover prior context, run at session start:**
\`\`\`bash
source \$HOME/.claude/get-shit-done/bin/lib/gastown.sh
gt seance ${bead_id} --json | python3 -c "
import sys, json
events = json.load(sys.stdin)
for e in events[-5:]:  # Last 5 events
    print(f'=== {e.get(\"timestamp\", \"\")} ===')
    print(e.get('content', ''))
    print()
"
\`\`\`

**Resume guidance:**
- Review prior events to understand what was completed before interruption
- Continue from the last completed checkpoint, not from the beginning
- Do NOT redo work already confirmed in prior events
GSD_SEANCE_BLOCK
}

# format_plan_notes()
# Formats GSD plan content into the bead notes markdown that polecats read at gt prime time.
# The format is designed so a polecat can begin work from notes alone,
# without reading .planning/ itself.
#
# RESUME SCENARIOS — see lib/seance.sh
#   For full Seance predecessor-context injection on resumed or re-dispatched polecats,
#   use the three functions in lib/seance.sh BEFORE calling format_plan_notes():
#     1. get_seance_predecessors(bead_id) — discover predecessor session IDs
#     2. build_seance_context(bead_id)    — query predecessors, build markdown block
#     3. inject_seance_into_notes(bead_id, ctx) — write block into bead notes
#   Then call format_plan_notes() with is_resume="true" (arg $9) so the lightweight
#   seance_context_block() hint is also embedded in the formatted notes.
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
#   $9 — is_resume (optional; "true" when re-dispatching a bead — appends Seance context block)
#        Existing 8-arg callers unaffected: is_resume defaults to "false", no Seance block added.
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
  local is_resume="${9:-false}"   # NEW: pass "true" when re-dispatching a bead

  # Derive project root from plan path
  local project_dir
  project_dir=$(python3 -c "import os; p='${plan_path}'; idx=p.find('/.planning/'); print(p[:idx] if idx >= 0 else os.path.dirname(p))" 2>/dev/null || echo "")

  # Generate Seance context if this is a resume (RESIL-04)
  local seance_section=""
  if [ "$is_resume" = "true" ] && [ -n "$bead_id" ]; then
    seance_section=$(seance_context_block "$bead_id")
  fi

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
${seance_section}
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

# =============================================================================
# v2 CONVOY HANDOFF FUNCTIONS (added Phase 06: mayor-delegation)
# =============================================================================

# launch_convoy()
# Stages and launches a convoy for all GSD phase beads in one atomic call.
# Uses: gt convoy stage <title> <bead-id...> --launch --json
# This is the v2 convoy handoff path — replaces create_phase_convoy + dispatch_plan_to_polecat.
#
# Args:
#   $1 — phase_num (e.g., "06")
#   $2 — phase_name (e.g., "mayor-delegation")
#   $3 — bead_ids (space-separated string: "gt-abc gt-def gt-ghi")
#
# Outputs: convoy_id on stdout (e.g., "hq-cv-xxxxx"); progress/errors on stderr.
# Returns: 0 on success, 1 on failure.
#
# JSON schema from gt convoy stage --launch --json (VERIFIED: convoy_stage.go StageResult):
# {
#   "status": "staged_ready",      // or "staged_warnings", "error"
#   "convoy_id": "hq-cv-xyz",
#   "waves": [{ "number": 1, "tasks": [...] }],
#   "errors": [],
#   "warnings": []
# }
launch_convoy() {
  local phase_num="${1:?phase_num required}"
  local phase_name="${2:?phase_name required}"
  local bead_ids_str="${3:?bead_ids required}"

  local convoy_title="GSD Phase ${phase_num}: ${phase_name}"

  # Convert space-separated bead IDs to array
  local bead_ids=()
  read -ra bead_ids <<< "$bead_ids_str"

  if [ "${#bead_ids[@]}" -eq 0 ]; then
    echo "ERROR: launch_convoy requires at least one bead ID" >&2
    return 1
  fi

  local result exit_code=0
  result=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin" \
    "$(gt_cmd)" convoy stage \
      "$convoy_title" \
      "${bead_ids[@]}" \
      --launch \
      --json \
      2>&1) || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    echo "ERROR: gt convoy stage --launch failed (exit $exit_code): $result" >&2
    return 1
  fi

  # Parse convoy_id from JSON response
  local convoy_id
  convoy_id=$(echo "$result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    status = data.get('status', '')
    if status == 'error':
        errors = data.get('errors', [])
        sys.stderr.write('ERROR: convoy stage errors: ' + str(errors) + '\n')
        sys.exit(1)
    cid = data.get('convoy_id', '')
    if not cid:
        sys.stderr.write('ERROR: convoy stage returned no convoy_id\n')
        sys.exit(1)
    print(cid)
except Exception as e:
    sys.stderr.write(f'ERROR: failed to parse convoy stage JSON: {e}\n')
    sys.exit(1)
" 2>&1) || return 1

  echo "$convoy_id"
}

# =============================================================================
# PHASE 07 — WITNESS INTEGRATION (WITNESS-01, WITNESS-02)
# =============================================================================

# tail_witness_events()
# Tails ~/gt/.events.jsonl (or <town_root>/.events.jsonl) for Witness-emitted events
# matching the given pattern. Exits when a matching event is found or timeout is reached.
#
# Event types of interest (from gastown/internal/events/events.go):
#   patrol_started, polecat_checked, polecat_nudged, escalation_sent,
#   escalation_acked, escalation_closed, patrol_complete
#
# Args:
#   $1 — town_root: path to the gastown town root (default: ~/gt)
#   $2 — event_type_pattern: grep-compatible pattern matched against "type" field
#          e.g., "patrol_complete" or "polecat_nudged\|escalation_sent"
#   $3 — timeout: seconds before giving up (default: 300)
#
# Outputs: matching event JSON line on stdout; "WITNESS_TIMEOUT" on timeout.
# Returns: 0 when a match is found, 1 on timeout or missing events file.
tail_witness_events() {
  local town_root="${1:-$GT_TOWN_DIR}"
  local event_type_pattern="${2:-patrol_complete}"
  local timeout="${3:-300}"

  local events_file="${town_root}/.events.jsonl"
  if [ ! -f "$events_file" ]; then
    echo "WARNING: events file not found: $events_file" >&2
    echo "WITNESS_TIMEOUT"
    return 1
  fi

  local start_time
  start_time=$(date +%s)

  # tail -F follows the file even if rotated. We filter each new line with python3
  # so we can parse the JSON "type" field rather than doing a fragile grep on raw JSON.
  while true; do
    local elapsed=$(( $(date +%s) - start_time ))
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "WITNESS_TIMEOUT: no matching event after ${elapsed}s (pattern: ${event_type_pattern})"
      return 1
    fi

    # Read at most the last 500 lines (in case of large file) plus any new ones
    # We sample each poll cycle rather than blocking on tail -F to keep the function
    # usable in both interactive and non-interactive shells.
    local match
    match=$(tail -n 200 "$events_file" 2>/dev/null | python3 - "$event_type_pattern" <<'PYEOF'
import sys, json

pattern_parts = sys.argv[1].split("\\|")
lines = sys.stdin.read().splitlines()
# Check from most recent backwards
for line in reversed(lines):
    line = line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
        etype = event.get("type", "")
        if any(p in etype for p in pattern_parts):
            print(json.dumps(event))
            sys.exit(0)
    except Exception:
        continue
PYEOF
)

    if [ -n "$match" ]; then
      echo "$match"
      return 0
    fi

    sleep 5
  done
}

# check_witness_status()
# Calls `gt witness status <rig> --json` and returns the parsed status.
# Non-fatal: returns a safe default JSON if witness is not running or gt fails.
#
# Args:
#   $1 — rig_name: gastown rig name (e.g., "gastown")
#
# Outputs: JSON object on stdout:
#   {
#     "running": true|false,
#     "rig_name": "gastown",
#     "session": "gt-gastown-witness",      // omitted when not running
#     "monitored_polecats": ["Toast", ...]  // omitted when not running
#   }
# Returns: 0 always (callers check .running field).
check_witness_status() {
  local rig_name="${1:?rig_name required}"

  local result exit_code=0
  result=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin" \
    "$(gt_cmd)" witness status "$rig_name" --json 2>/dev/null) || exit_code=$?

  if [ "$exit_code" -ne 0 ] || [ -z "$result" ]; then
    # Witness not running or gt unavailable — return safe default
    echo "{\"running\":false,\"rig_name\":\"${rig_name}\",\"monitored_polecats\":[]}"
    return 0
  fi

  # Validate it looks like JSON; if not, return safe default
  echo "$result" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Ensure monitored_polecats is always present (may be absent when not running)
    d.setdefault('monitored_polecats', [])
    print(json.dumps(d))
except Exception:
    print('{\"running\":false,\"rig_name\":\"" + rig_name + "\",\"monitored_polecats\":[]}')
" 2>/dev/null || echo "{\"running\":false,\"rig_name\":\"${rig_name}\",\"monitored_polecats\":[]}"
}

# poll_convoy_status()
# Polls gt convoy status <id> --json until status="closed" or timeout.
# This is the v2 completion signal path — replaces wait_for_polecats().
#
# Enhanced (Phase 07 — Witness Integration): On each poll cycle, also calls
# check_witness_status() to detect Witness-reported stalled/crashed polecats.
# When a stalled polecat is found that belongs to this convoy, emits:
#   CONVOY_POLECAT_STALLED: <polecat-name> (rig: <rig>)
# and optionally records a failed SUMMARY stub so the GSD pipeline has an artifact.
#
# Args:
#   $1 — convoy_id (e.g., "hq-cv-xxxxx")
#   $2 — poll_interval: seconds between checks (default: 60)
#   $3 — timeout_seconds: max wait time (default: 7200 = 2 hours)
#   $4 — rig_name: gastown rig to pass to check_witness_status (default: "gastown")
#
# Outputs: progress lines to stdout; "CONVOY_DONE" on close; "CONVOY_TIMEOUT" on timeout.
# Returns: 0 when convoy closed, 1 on timeout.
#
# JSON schema from gt convoy status --json (VERIFIED: convoy.go lines 1808-1837):
# {
#   "id": "hq-cv-xyz",
#   "status": "open",              // "open" | "closed" | "staged_ready" | "staged_warnings"
#   "completed": 2,
#   "total": 3
# }
poll_convoy_status() {
  local convoy_id="${1:?convoy_id required}"
  local poll_interval="${2:-60}"
  local timeout_seconds="${3:-7200}"
  local rig_name="${4:-gastown}"  # Phase 07: rig for Witness status checks

  local start_time
  start_time=$(date +%s)

  # Phase 07: track which polecats we have already emitted STALLED for this session
  # to avoid spamming the log on every poll cycle.
  declare -A _stalled_reported

  while true; do
    local elapsed=$(( $(date +%s) - start_time ))

    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      echo "CONVOY_TIMEOUT: waited ${elapsed}s for convoy $convoy_id to close"
      return 1
    fi

    local status_json
    status_json=$(cd "$GT_TOWN_DIR" && \
      PATH="$PATH:${HOME}/go/bin" \
      "$(gt_cmd)" convoy status "$convoy_id" --json 2>/dev/null || echo "{}")

    local status completed total
    status=$(echo "$status_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

    completed=$(echo "$status_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('completed', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

    total=$(echo "$status_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('total', '?'))
except:
    print('?')
" 2>/dev/null || echo "?")

    # Phase 07 — WITNESS-01: Check Witness status on every poll cycle.
    # If Witness reports stalled polecats that are part of this convoy's rig,
    # emit CONVOY_POLECAT_STALLED so the orchestrator can act (WITNESS-02).
    local witness_json
    witness_json=$(check_witness_status "$rig_name")

    local witness_running
    witness_running=$(echo "$witness_json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print('true' if d.get('running') else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

    if [ "$witness_running" = "true" ]; then
      # Extract monitored polecats from Witness status.
      # Witness does not directly report "stalled" polecats via gt witness status --json;
      # instead we correlate with polecat list --json (state == "stuck" or "stalled")
      # filtered to polecats the Witness is monitoring.
      local polecat_json
      polecat_json=$(cd "$GT_TOWN_DIR" && \
        PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
        "$(gt_cmd)" polecat list "$rig_name" --json 2>/dev/null || echo "[]")

      # Emit CONVOY_POLECAT_STALLED for each stalled/stuck polecat not yet reported.
      # Also emit a WITNESS-02 failure SUMMARY stub for affected beads.
      while IFS= read -r stalled_entry; do
        [ -z "$stalled_entry" ] && continue
        local polecat_name bead_id_for_stall
        polecat_name=$(echo "$stalled_entry" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('name', ''))
except:
    print('')
" 2>/dev/null || echo "")
        bead_id_for_stall=$(echo "$stalled_entry" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('issue', ''))
except:
    print('')
" 2>/dev/null || echo "")

        if [ -z "$polecat_name" ]; then
          continue
        fi

        # Skip if already reported this session
        if [ "${_stalled_reported[$polecat_name]+_}" ]; then
          continue
        fi
        _stalled_reported["$polecat_name"]=1

        echo "CONVOY_POLECAT_STALLED: ${polecat_name} (rig: ${rig_name}, bead: ${bead_id_for_stall:-unknown})"

        # WITNESS-02: Auto-record failure — write a failed SUMMARY stub for the bead
        # so the GSD verification pipeline has an artifact to process.
        if [ -n "$bead_id_for_stall" ]; then
          local resolved_plan
          resolved_plan=$(resolve_plan_from_bead "$bead_id_for_stall" "${PROJECT_DIR:-$(pwd)}")
          if [ -n "$resolved_plan" ]; then
            local fail_phase_dir fail_plan_id
            read -r fail_phase_dir fail_plan_id <<< "$resolved_plan"
            reconstruct_summary_from_bead "$bead_id_for_stall" "$fail_phase_dir" "$fail_plan_id" || true
            echo "WITNESS-02: failure SUMMARY recorded for bead ${bead_id_for_stall} (polecat: ${polecat_name})"
          fi
        fi
      done < <(echo "$polecat_json" | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    for item in items:
        if item.get('state') in ('stuck', 'stalled'):
            import json as j
            print(j.dumps(item))
except:
    pass
" 2>/dev/null)
    fi

    if [ "$status" = "closed" ]; then
      echo "CONVOY_DONE: convoy $convoy_id closed (${completed}/${total} beads)"
      return 0
    fi

    echo "CONVOY_POLLING: convoy=$convoy_id status=$status completed=${completed}/${total} (elapsed ${elapsed}s)"
    sleep "$poll_interval"
  done
}

# =============================================================================
# REFINERY INTEGRATION (Phase 8)
# =============================================================================
#
# When Refinery is active for a rig, it owns the merge queue. GSD must NOT
# perform its own worktree merge (execute-phase.md step 5.5) when Refinery
# is handling merges.
#
# Dispatch path behavior:
#   - v2 convoy path (Phase 6): already skips GSD's worktree merge because
#     convoys manage their own lifecycle via gt done → Refinery.
#   - Direct polecat dispatch: same — polecats call gt done which creates the
#     MR bead (gt:merge-request wisp) and notifies Witness → Refinery.
#
# GSD orchestrators that need to wait for a merge can call:
#   wait_for_refinery_merge <mr_bead_id> [timeout_seconds]
#
# GSD orchestrators that need to check if Refinery is active before deciding
# whether to merge themselves can call:
#   detect_refinery_active <rig_name>

# wait_for_refinery_merge()
# Polls a merge-request bead until Refinery closes it (merged) or rejects it.
#
# Refinery closes the MR bead with status "closed" on success, or adds a
# rejection tag / sets status "rejected" on failure.
#
# Args:
#   $1 — mr_bead_id: the gt:merge-request bead ID (e.g., "gt-mr-abc123")
#   $2 — timeout: seconds to wait before returning "timeout" (default: 300)
#
# Outputs: one of "merged" | "failed" | "timeout" on stdout; progress on stderr.
# Returns: 0 always (caller checks stdout to decide what to do).
wait_for_refinery_merge() {
  local mr_bead_id="${1:?mr_bead_id required}"
  local timeout="${2:-300}"
  local poll_interval=10
  local elapsed=0

  echo "REFINERY_WAIT: watching MR bead ${mr_bead_id} (timeout ${timeout}s)" >&2

  while [ "$elapsed" -lt "$timeout" ]; do
    local bead_json
    bead_json=$(cd "$GT_RIG_DIR" && \
      PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
      "${BD_BIN}" show "$mr_bead_id" --json 2>/dev/null || echo "{}")

    local bead_status
    bead_status=$(echo "$bead_json" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('status', ''))
except:
    print('')
" 2>/dev/null || echo "")

    local bead_tags
    bead_tags=$(echo "$bead_json" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    tags = d.get('tags', [])
    print(' '.join(tags))
except:
    print('')
" 2>/dev/null || echo "")

    # Refinery signals failure via a rejection tag or explicit status
    if echo "$bead_tags" | grep -qw "rejected" || [ "$bead_status" = "rejected" ]; then
      echo "REFINERY_WAIT: MR bead ${mr_bead_id} was rejected" >&2
      echo "failed"
      return 0
    fi

    # Refinery signals success by closing the MR bead
    if [ "$bead_status" = "closed" ]; then
      echo "REFINERY_WAIT: MR bead ${mr_bead_id} closed (merged)" >&2
      echo "merged"
      return 0
    fi

    echo "REFINERY_WAIT: status=${bead_status:-unknown} elapsed=${elapsed}s — sleeping ${poll_interval}s" >&2
    sleep "$poll_interval"
    elapsed=$(( elapsed + poll_interval ))
  done

  echo "REFINERY_WAIT: timed out after ${timeout}s waiting for ${mr_bead_id}" >&2
  echo "timeout"
  return 0
}

# detect_refinery_active()
# Returns "true" if Refinery is active for a given rig; "false" otherwise.
#
# Detection strategy (in order):
#   1. Check gt rig config for a refinery_enabled flag.
#   2. Check for a running Refinery process (gastown wisp gt:refinery).
#   3. Return "false" if neither check confirms Refinery.
#
# Args:
#   $1 — rig_name: name of the rig to check (e.g., "gastown")
#
# Outputs: "true" or "false" on stdout.
# Returns: 0 always.
detect_refinery_active() {
  local rig_name="${1:?rig_name required}"

  # Check 1: gt rig config --json for refinery_enabled key
  local rig_config
  rig_config=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
    "$(gt_cmd)" rig config "$rig_name" --json 2>/dev/null || echo "{}")

  local refinery_flag
  refinery_flag=$(echo "$rig_config" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    # Support nested: {refinery: {enabled: true}} or flat {refinery_enabled: true}
    refinery = d.get('refinery', {})
    if isinstance(refinery, dict):
        val = refinery.get('enabled', None)
    else:
        val = None
    if val is None:
        val = d.get('refinery_enabled', None)
    print('true' if val is True or val == 'true' else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

  if [ "$refinery_flag" = "true" ]; then
    echo "true"
    return 0
  fi

  # Check 2: look for a live Refinery wisp in the rig's active wisps
  local wisp_list
  wisp_list=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
    "$(gt_cmd)" wisp list "$rig_name" --json 2>/dev/null || echo "[]")

  local has_refinery
  has_refinery=$(echo "$wisp_list" | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    for item in items:
        kind = item.get('kind', '') or item.get('type', '')
        if 'refinery' in kind.lower():
            print('true')
            sys.exit(0)
    print('false')
except:
    print('false')
" 2>/dev/null || echo "false")

  echo "$has_refinery"
  return 0
}
