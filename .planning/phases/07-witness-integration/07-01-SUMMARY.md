---
phase: "07"
plan: "01"
subsystem: gastown.sh
tags: [witness, monitoring, stall-detection, events]
dependency_graph:
  requires: [06-01]
  provides: [tail_witness_events, check_witness_status, poll_convoy_status_v2]
  affects: [execute-phase dispatch loop]
tech_stack:
  added: []
  patterns: [events-jsonl-tail, gt-witness-status-json, stall-to-summary-stub]
key_files:
  created: []
  modified:
    - lib/gastown.sh
    - ~/.claude/get-shit-done/bin/lib/gastown.sh
decisions:
  - tail_witness_events uses poll-with-sleep rather than blocking tail -F for shell compatibility
  - check_witness_status returns safe-default JSON on any failure so callers never need to null-check
  - poll_convoy_status stall detection deduplicates via associative array to avoid log spam
  - WITNESS-02 failure stub writes reuse existing reconstruct_summary_from_bead (no new code path)
metrics:
  duration: "109s"
  completed: "2026-04-12"
  tasks: 1
  files: 2
requirements: [WITNESS-01, WITNESS-02]
---

# Phase 07 Plan 01: Witness Integration Summary

**One-liner:** Real-time Witness stall detection via .events.jsonl tail and gt witness status --json, with auto-recorded failure SUMMARY stubs on polecat crash.

## What Was Built

Three additive changes to `lib/gastown.sh` (WITNESS-01 + WITNESS-02):

### `tail_witness_events(town_root, event_type_pattern, timeout)`

Samples `<town_root>/.events.jsonl` every 5 seconds for Witness-emitted event types. Uses a poll-with-sleep pattern instead of blocking `tail -F` so it works in both interactive and non-interactive shells. Event type matching is done with Python JSON parsing (not fragile grep on raw JSON). Returns the matching event JSON line on stdout or `WITNESS_TIMEOUT` on expiry.

### `check_witness_status(rig_name)`

Wraps `gt witness status <rig> --json`. Returns the parsed status JSON with `monitored_polecats` always present. On any failure (Witness not running, `gt` unavailable, parse error) returns a safe-default `{"running":false,...}` — callers never need to null-check.

### `poll_convoy_status()` enhanced (4th arg: `rig_name`)

Added Witness integration to every poll cycle:
1. Calls `check_witness_status(rig_name)` on each iteration
2. If Witness is running, correlates its rig against `gt polecat list <rig> --json` for `stuck`/`stalled` state
3. Emits `CONVOY_POLECAT_STALLED: <name> (rig: <rig>, bead: <id>)` on first detection (deduplicated per session via associative array)
4. WITNESS-02: calls `reconstruct_summary_from_bead` to write a failure SUMMARY stub so the GSD verification pipeline has an artifact

New parameter is positional and optional — existing 3-argument callers are unaffected (defaults to `rig_name="gastown"`).

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Witness integration | 3067702 | lib/gastown.sh |

## Deviations from Plan

**1. [Rule 2 - Missing critical functionality] Sync installed copy**

- **Found during:** Post-edit verification
- **Issue:** `~/.claude/get-shit-done/bin/lib/gastown.sh` is a separate copy (not a symlink) that `execute-phase.md` actually sources at runtime. Updating only the repo copy would leave the live install stale.
- **Fix:** Copied updated `lib/gastown.sh` to installed location.
- **Files modified:** `~/.claude/get-shit-done/bin/lib/gastown.sh`
- **Commit:** included in 3067702 (same commit — file is outside git tracking of this repo)

## Known Stubs

None. All three functions are fully wired:
- `tail_witness_events` reads live `.events.jsonl`
- `check_witness_status` calls real `gt witness status --json`
- `poll_convoy_status` integration calls both and acts on stall signals

## Threat Flags

None. Changes are read-only observers of gastown internals (tail JSONL, call gt CLI). No new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

- [x] `lib/gastown.sh` exists and passes `bash -n`
- [x] `tail_witness_events` function present at line 980
- [x] `check_witness_status` function present at line 1053
- [x] `poll_convoy_status` enhanced at line 1106 (new `rig_name` arg, Witness check loop)
- [x] Commit 3067702 exists
- [x] Installed copy synced and passes `bash -n`
