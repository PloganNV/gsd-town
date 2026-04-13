#!/usr/bin/env bash
# seance.sh — Seance predecessor-session context helpers for GSD-Town
#
# Provides three functions for SEANCE-01 and SEANCE-02 requirements:
#
#   get_seance_predecessors  — discovers predecessor session IDs for a bead
#   build_seance_context     — queries each predecessor and returns a markdown block
#   inject_seance_into_notes — appends the Seance block to an existing bead's notes
#
# USAGE
#   source "$HOME/.claude/get-shit-done/bin/lib/seance.sh"
#
# REQUIREMENTS
#   - gt binary at ~/.local/bin/gt (or in PATH)
#   - gt prime --hook wired as a SessionStart hook (makes sessions discoverable)
#   - Claude agent preset with SupportsForkSession: true (required for --fork-session)
#   - python3 available (used for JSON parsing — guaranteed on macOS)
#
# SEANCE IS OPT-IN AT TWO LEVELS
#   1. Sessions are only discoverable if gt prime --hook is wired as a SessionStart hook.
#      Without it, no session_start events are emitted and gt seance list returns nothing.
#   2. Talking to a predecessor requires an explicit gt seance --talk <session-id> call.
#      These functions prepare that call; they do not initiate Claude sessions themselves.
#
# WHEN TO USE
#   SEANCE-01 (resume):    polecat re-dispatched for the same bead — call before gt prime
#   SEANCE-02 (re-dispatch): failed polecat re-dispatched with full prior history injected
#
# RELATIONSHIP TO gastown.sh
#   gastown.sh: format_plan_notes() calls seance_context_block() which embeds a
#   "run this at session start" code snippet into bead notes.  That snippet runs
#   gt seance <bead-id> --json and prints raw events.
#
#   seance.sh goes further: it queries predecessors interactively via gt seance --talk
#   and distills the responses into a pre-built markdown summary that polecats can
#   read without having to invoke Claude themselves.  Use seance.sh when you want
#   richer, pre-distilled context; use gastown.sh's seance_context_block() when you
#   want a lightweight "here is how to query if you want to" hint.

set -euo pipefail

GT_BIN="${HOME}/.local/bin/gt"
GT_TOWN_DIR="${HOME}/gt"

# ---------------------------------------------------------------------------
# _gt_seance_cmd()  [internal]
# Returns the gt binary path (PATH or absolute fallback).
# ---------------------------------------------------------------------------
_gt_seance_cmd() {
  if command -v gt >/dev/null 2>&1; then
    echo "gt"
  else
    echo "$GT_BIN"
  fi
}

# ---------------------------------------------------------------------------
# get_seance_predecessors()
# Discovers predecessor session IDs for a bead by scanning .events.jsonl for
# session_start events whose topic matches "assigned:<bead_id>".
#
# Falls back to gt seance --role polecat --rig gastown if jq is available and
# the events file cannot be read.
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#
# Outputs: newline-delimited list of session IDs on stdout (may be empty).
# Returns: 0 always (empty output means no predecessors found).
#
# Example:
#   predecessors=$(get_seance_predecessors "gt-abc123")
#   echo "$predecessors"   # abc-def-001\nabc-def-002
# ---------------------------------------------------------------------------
get_seance_predecessors() {
  local bead_id="${1:?bead_id required}"
  local events_file="${GT_TOWN_DIR}/.events.jsonl"

  # Primary path: scan .events.jsonl for session_start events for this bead.
  # Topic format: "assigned:<bead-id>" (verified: session/startup.go SessionPayload).
  if [ -f "$events_file" ]; then
    local session_ids
    session_ids=$(python3 - "$bead_id" "$events_file" <<'PYEOF'
import sys, json

bead_id = sys.argv[1]
events_file = sys.argv[2]
target_topic = f"assigned:{bead_id}"

session_ids = []
try:
    with open(events_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") != "session_start":
                continue
            payload = event.get("payload", {})
            if payload.get("topic") == target_topic:
                sid = payload.get("session_id", "")
                if sid and sid not in session_ids:
                    session_ids.append(sid)
except Exception:
    pass

for sid in session_ids:
    print(sid)
PYEOF
    2>/dev/null || echo "")

    if [ -n "$session_ids" ]; then
      echo "$session_ids"
      return 0
    fi
  fi

  # Fallback: use gt seance discovery mode filtered by rig.
  # This covers cases where .events.jsonl is unavailable (different town root, permissions).
  # gt seance --role polecat --rig gastown returns a table; we grep for lines
  # containing the bead_id in the topic column, then extract the session ID.
  local gt_bin
  gt_bin=$(_gt_seance_cmd)

  local seance_output
  seance_output=$(cd "$GT_TOWN_DIR" && \
    PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
    "$gt_bin" seance --role polecat --rig gastown 2>/dev/null || echo "")

  if [ -z "$seance_output" ]; then
    echo ""
    return 0
  fi

  # The table output contains the session-id and topic in tab/space-aligned columns.
  # Filter lines matching the bead_id in the topic and extract the session ID (first field).
  echo "$seance_output" | python3 - "$bead_id" <<'PYEOF'
import sys, re

bead_id = sys.argv[1]
for line in sys.stdin:
    if bead_id not in line:
        continue
    # First whitespace-delimited token is the session ID (UUID-like)
    parts = line.split()
    if parts:
        sid = parts[0]
        # Basic sanity: session IDs contain hyphens and are not header words
        if "-" in sid and not sid.startswith("#"):
            print(sid)
PYEOF
  return 0
}

# ---------------------------------------------------------------------------
# build_seance_context()
# Queries each predecessor session via gt seance --talk and concatenates the
# responses into a single markdown context block.
#
# Queries each predecessor with a fixed prompt:
#   "What did you accomplish? What was left undone? What should I know?"
#
# This function is intentionally slow (one claude --fork-session per predecessor).
# Call it only for resumed or re-dispatched polecats, not on first dispatch.
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#
# Outputs: markdown string on stdout (empty if no predecessors found).
# Returns: 0 always.
#
# Example:
#   ctx=$(build_seance_context "gt-abc123")
#   echo "$ctx"
# ---------------------------------------------------------------------------
build_seance_context() {
  local bead_id="${1:?bead_id required}"

  local predecessor_ids
  predecessor_ids=$(get_seance_predecessors "$bead_id")

  if [ -z "$predecessor_ids" ]; then
    echo ""
    return 0
  fi

  local gt_bin
  gt_bin=$(_gt_seance_cmd)

  local context_parts=()
  local session_num=0
  local query="What did you accomplish? What was left undone? What should I know?"

  while IFS= read -r session_id; do
    [ -z "$session_id" ] && continue
    session_num=$((session_num + 1))

    local response
    response=$(cd "$GT_TOWN_DIR" && \
      PATH="$PATH:${HOME}/go/bin:/opt/homebrew/bin" \
      "$gt_bin" seance --talk "$session_id" -p "$query" 2>/dev/null \
      || echo "(seance query failed for session $session_id)")

    context_parts+=("### Predecessor Session ${session_num} (${session_id})

${response}")
  done <<< "$predecessor_ids"

  if [ "${#context_parts[@]}" -eq 0 ]; then
    echo ""
    return 0
  fi

  # Emit the full block
  local joined
  joined=$(printf '%s\n\n' "${context_parts[@]}")

  cat <<SEANCE_BLOCK

## Seance Predecessor Context

Predecessor session(s) were found for bead **${bead_id}**. The following context
was retrieved by querying each predecessor with:
> "${query}"

${joined}
---
*Seance context generated by lib/seance.sh — build_seance_context()*
SEANCE_BLOCK
}

# ---------------------------------------------------------------------------
# inject_seance_into_notes()
# Reads the current bead notes, appends the provided Seance context block, and
# writes the updated notes back to the bead via bd update --notes.
#
# Call this immediately before re-dispatching a failed or timed-out polecat so
# the resumed polecat has full prior context available at gt prime time.
#
# Args:
#   $1 — bead_id (e.g., "gt-abc123")
#   $2 — seance_context (markdown string returned by build_seance_context())
#
# Outputs: status message on stdout.
# Returns: 0 on success, 1 on failure.
#
# Example:
#   ctx=$(build_seance_context "$BEAD_ID")
#   inject_seance_into_notes "$BEAD_ID" "$ctx"
# ---------------------------------------------------------------------------
inject_seance_into_notes() {
  local bead_id="${1:?bead_id required}"
  local seance_context="${2:-}"

  # Guard: nothing to inject
  if [ -z "$seance_context" ]; then
    echo "seance.sh: no context to inject for $bead_id — skipping"
    return 0
  fi

  local bd_bin="${HOME}/go/bin/bd"
  local rig_dir="${HOME}/gt/gastown/mayor/rig"

  if [ ! -x "$bd_bin" ]; then
    echo "ERROR: bd binary not found at $bd_bin" >&2
    return 1
  fi

  if [ ! -d "$rig_dir" ]; then
    echo "ERROR: rig dir not found: $rig_dir" >&2
    return 1
  fi

  # Read current notes
  local current_notes
  current_notes=$(cd "$rig_dir" && \
    "$bd_bin" show "$bead_id" --json 2>/dev/null \
    | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    items = data if isinstance(data, list) else [data]
    print(items[0].get('description', '') if items else '')
except Exception:
    print('')
" 2>/dev/null || echo "")

  # Append Seance context to existing notes
  local updated_notes
  updated_notes="${current_notes}
${seance_context}"

  # Write back
  local raw_output exit_code=0
  raw_output=$(cd "$rig_dir" && \
    "$bd_bin" update "$bead_id" \
      --notes "$updated_notes" \
      2>&1) || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    echo "ERROR: bd update failed for $bead_id (exit $exit_code): $raw_output" >&2
    return 1
  fi

  echo "seance.sh: Seance context injected into bead $bead_id notes"
  return 0
}
