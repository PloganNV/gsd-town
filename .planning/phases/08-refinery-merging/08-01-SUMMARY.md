---
phase: 08
plan: 01
subsystem: gastown-integration
tags: [refinery, merge-queue, polecat, gastown]
dependency_graph:
  requires: [07-witness-integration]
  provides: [refinery-merge-wait, refinery-detection]
  affects: [lib/gastown.sh]
tech_stack:
  added: []
  patterns: [bash-polling, bd-json-api, gt-rig-config]
key_files:
  created: []
  modified: [lib/gastown.sh]
decisions:
  - Polling via bd show --json rather than watching .events.jsonl — simpler, no file-watching dependency
  - detect_refinery_active checks rig config first, then live wisps — config is authoritative when set
  - Both functions return 0 always; caller reads stdout to branch on result — consistent with existing gastown.sh pattern
metrics:
  duration: 120s
  completed: "2026-04-13T23:03:32Z"
---

# Phase 8 Plan 1: Refinery Merging Summary

**One-liner:** Bash helper functions for GSD to wait on Refinery merge-queue results and detect whether Refinery is active for a rig, without touching execute-phase.md.

## What Was Built

Two new functions appended to `lib/gastown.sh`, plus a comment block documenting the merge ownership contract:

### `wait_for_refinery_merge(mr_bead_id, timeout=300)`

Polls `bd show <mr-bead-id> --json` every 10 seconds until:
- `status == "closed"` → prints `merged` (Refinery merged the branch)
- `status == "rejected"` or tag `rejected` present → prints `failed`
- Elapsed time exceeds timeout → prints `timeout`

Returns 0 in all cases; caller branches on stdout. Progress lines go to stderr so they don't pollute capture.

### `detect_refinery_active(rig_name)`

Checks in order:
1. `gt rig config <rig> --json` — looks for `refinery.enabled: true` or flat `refinery_enabled: true`
2. `gt wisp list <rig> --json` — scans for any wisp whose kind/type contains "refinery"

Prints `true` or `false`. Returns 0 always.

### Comment block (lines 1255-1275)

Documents the merge ownership contract:
- v2 convoy path (Phase 6) already skips GSD's worktree merge because `gt done` creates the MR bead and hands off to Refinery
- Direct polecat dispatch: same — polecats call `gt done`, Refinery picks up the MR bead
- execute-phase.md does NOT need modification

## Requirements Satisfied

- **REFINERY-01:** Polecat branches submit to Refinery merge queue — documented contract + helper for orchestrators to confirm merge completion without doing it themselves.
- **REFINERY-02:** GSD orchestrator waits for Refinery merge confirmation — `wait_for_refinery_merge()` provides the blocking wait primitive.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- `lib/gastown.sh` modified: FOUND
- Commit fc8fb67: FOUND
- `bash -n lib/gastown.sh`: PASSED

## Self-Check: PASSED
