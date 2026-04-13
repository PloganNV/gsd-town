---
phase: "09"
plan: "01"
subsystem: bead-state
tags: [beads, state-management, convoy, requirements]
requires: [gastown.sh, gastown.json registry]
provides: [bead-state.sh, generate_state_from_beads, read_plan_result_from_bead, check_phase_completion_from_convoy, sync_requirements_from_beads]
affects: [STATE.md, REQUIREMENTS.md]
tech_stack:
  added: []
  patterns: [bead-query-via-bd-show, ndjson-bd-list, convoy-child-count-aggregation]
key_files:
  created:
    - lib/bead-state.sh
  modified: []
decisions:
  - "STATE.md is a generated view, not a truth store — beads own status"
  - "bd show returns an array; always take element [0] via python3"
  - "Convoy status does NOT auto-propagate — GSD must count closed children explicitly"
  - "Used python3 subprocesses inside bash for JSON parsing consistency with gastown.sh"
  - "sync_requirements uses line-level regex replacement, not structured frontmatter parsing"
metrics:
  duration_seconds: 90
  completed_date: "2026-04-13"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 9 Plan 01: Beads as Truth Summary

Bead-backed state management module: STATE.md regenerated from live bead data, verifier reads plan results directly from bead notes, phase completion derived from convoy child counts.

## What Was Built

**`lib/bead-state.sh`** — new standalone module (does not modify gastown.sh or any existing file). Four public functions implementing BEADS-01 through BEADS-03:

### `generate_state_from_beads(project_dir)` — BEADS-01

Reads `.planning/gastown.json` registry, queries each registered bead via `bd show --json`, and writes a new `.planning/STATE.md` from live bead data. STATE.md is marked as a generated view with a regeneration command at the top.

- Preserves total/completed plan counts in frontmatter for tooling
- Includes per-plan status icons: `[done]`, `[running]`, `[open]`, `[closed]`
- Notes when bead notes field is populated ("results in bead")
- Handles missing registry gracefully (warns, returns 0)

### `read_plan_result_from_bead(bead_id)` — BEADS-02

Reads bead notes field and returns it on stdout — same content the polecat wrote before calling `gt done`. GSD verifier can consume this directly instead of reading SUMMARY.md from disk.

- Returns exit 1 with diagnostic message if notes are empty
- Uses `bd show --json` array unwrap (element [0])

### `check_phase_completion_from_convoy(convoy_id)` — BEADS-03

Queries convoy bead for its `children[]` list, then queries each child bead's `status` field. Returns `"complete"` / `"in-progress"` / `"failed"`.

- Does NOT rely on convoy auto-propagation (research finding: not guaranteed)
- Counts: closed → complete, tombstone/stuck → failed, everything else → open
- All children closed = phase done (BEADS-03)
- Emits per-child diagnostic lines to stderr

### `sync_requirements_from_beads(project_dir)` — bonus

Maps closed plan beads back to requirement references in REQUIREMENTS.md and marks checkboxes `[ ]` → `[x]` for any line referencing the completed plan_id.

## Key Design Decisions

**bd show returns an array — always unwrap [0].**
Per research finding from `.planning/phases/07-10-RESEARCH.md` (Phase 9 section): `bd show <id> --json` returns a JSON array. Every `_bs_bd_show()` call pipes through python3 to extract element [0]. This is consistent with the gastown source (`mail/mailbox.go:499`).

**bd list requires `--flat` for JSON.**
`bd list --json` alone does not produce JSON in bd v0.59+. All list calls use `--flat`. The helper `_bs_bd_list()` also handles the "No issues found." text response.

**Convoy children must be counted explicitly.**
The research confirmed (`gastown/internal/convoy/operations.go`) that convoy status auto-propagation is not reliable for GSD purposes. `check_phase_completion_from_convoy()` queries each child bead individually.

**python3 for JSON, not jq.**
Consistent with gastown.sh style. python3 is guaranteed present on macOS. jq is not reliably installed. All JSON parsing uses inline python3 heredocs or subprocess calls.

**STATE.md is explicitly labeled as generated.**
The generated STATE.md includes a prominent notice at the top that it is a view, not a source. This prevents confusion if the file is edited manually and then overwritten by a future `generate_state_from_beads()` call.

## Deviations from Plan

None — plan executed exactly as written. All four functions implemented. bash -n syntax check passed.

## Known Stubs

None. All four functions are fully wired. No placeholder data flows to any consumer.

## Self-Check: PASSED

- [x] `/Users/laul_pogan/Source/gsd-town/lib/bead-state.sh` exists
- [x] `bash -n` syntax check: OK
- [x] Commit `7e16e25` exists in git log
- [x] All four public functions present: `generate_state_from_beads`, `read_plan_result_from_bead`, `check_phase_completion_from_convoy`, `sync_requirements_from_beads`
