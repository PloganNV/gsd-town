---
phase: 10
plan: "01"
subsystem: seance-continuity
tags: [seance, polecat, resume, re-dispatch, context]
dependency_graph:
  requires: [gastown.sh, gt-seance-cli, bd-binary]
  provides: [lib/seance.sh]
  affects: [gastown.sh format_plan_notes comment, polecat resume flow]
tech_stack:
  added: []
  patterns: [events-jsonl-scan, gt-seance-talk, bd-update-notes]
key_files:
  created:
    - lib/seance.sh
  modified:
    - lib/gastown.sh
decisions:
  - Scan .events.jsonl directly for session_start/topic matching as primary path — avoids parsing gt seance table output
  - Fall back to gt seance --role discovery only when .events.jsonl is unavailable
  - build_seance_context uses a fixed handoff prompt for consistent predecessor responses
  - inject_seance_into_notes reads then appends — preserves existing bead notes
  - Comment-only change to gastown.sh format_plan_notes — no function body modifications
metrics:
  duration_seconds: 89
  completed_date: "2026-04-13"
  tasks_completed: 1
  files_modified: 2
---

# Phase 10 Plan 01: Seance Continuity Summary

Three-function bash module enabling Seance predecessor-context injection for resumed and re-dispatched polecats, with a documentation pointer added to gastown.sh.

## What Was Built

`lib/seance.sh` provides three composable functions:

**`get_seance_predecessors(bead_id)`**
Scans `~/gt/.events.jsonl` for `session_start` events whose `payload.topic` matches `assigned:<bead_id>`. Returns newline-delimited session IDs. Falls back to `gt seance --role polecat --rig gastown` table parsing when the events file is unavailable.

**`build_seance_context(bead_id)`**
Calls `get_seance_predecessors`, then for each session ID runs `gt seance --talk <id> -p "What did you accomplish? What was left undone? What should I know?"`. Concatenates responses into a single markdown block with per-predecessor sections.

**`inject_seance_into_notes(bead_id, seance_context)`**
Reads current bead notes via `bd show --json` (unwrapping the array at index 0), appends the Seance block, and writes back via `bd update --notes`. Safe no-op when context is empty.

**Comment added to `gastown.sh` `format_plan_notes()`**
A `RESUME SCENARIOS — see lib/seance.sh` block in the docstring explains the recommended call sequence: run all three seance.sh functions before calling `format_plan_notes()` with `is_resume=true`.

## Requirements Satisfied

| Requirement | How |
|-------------|-----|
| SEANCE-01: auto-query on resume | `get_seance_predecessors` + `build_seance_context` called before re-dispatch |
| SEANCE-02: full history on re-dispatch | `inject_seance_into_notes` writes pre-distilled block into bead notes before polecat primes |

## Decisions Made

- **Primary discovery via .events.jsonl scan** — more reliable than parsing `gt seance` table output; the events file is authoritative (verified: gastown/internal/events/events.go).
- **Fixed handoff prompt** — consistent question ("What did you accomplish? What was left undone? What should I know?") produces structured answers without per-call customization.
- **Append-not-replace for notes** — `inject_seance_into_notes` reads then appends to preserve existing bead notes written by `format_plan_notes`.
- **Comment-only modification to gastown.sh** — function bodies unchanged; docstring points to seance.sh. All 8-arg callers of `format_plan_notes` remain unaffected.
- **python3 for all JSON parsing** — consistent with gastown.sh convention; guaranteed on macOS; avoids jq dependency.

## Deviations from Plan

None - plan executed exactly as written.

The implementation spec described `gt seance list --json` as the discovery interface, but the research file confirmed the actual CLI is `gt seance --role polecat --rig <rig>` (table output, no `--json` flag). The primary path was implemented via `.events.jsonl` scan instead (more reliable, verified from source), with the `gt seance` table as fallback. This is a research-fidelity fix, not a behavioral deviation.

## Known Stubs

None. All three functions are fully wired. `build_seance_context` may return empty string on first dispatch (no predecessors) — this is correct behavior, not a stub.

## Self-Check: PASSED

- lib/seance.sh: FOUND
- lib/gastown.sh: FOUND (comment added, syntax OK)
- Commit 888b14d: FOUND
