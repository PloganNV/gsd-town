---
phase: "06-mayor-delegation"
plan: 01
subsystem: "dispatch"
tags: ["gastown", "convoy", "dispatch", "bash"]
dependency_graph:
  requires: []
  provides: ["launch_convoy", "poll_convoy_status", "convoy-dispatch-path"]
  affects: ["execute-phase.md", "lib/gastown.sh"]
tech_stack:
  added: []
  patterns: ["gt convoy stage --launch --json", "convoy status polling", "GT_CONVOY_CAPABLE feature flag"]
key_files:
  created: []
  modified:
    - "lib/gastown.sh"
    - "~/.claude/get-shit-done/workflows/execute-phase.md"
decisions:
  - "Used polling (gt convoy status --json) over push notifications (gt convoy watch) for completion signal — simpler, no gastown agent identity required"
  - "GT_CONVOY_CAPABLE detection via gt convoy stage --help exit code — zero-cost on unsupported gastown versions"
  - "Kept full v1 code path (dispatch_plan_to_polecat, wait_for_polecats) in elif branches — no v1 code removed"
  - "CONVOY_TIMEOUT writes failure SUMMARY.md per plan (T-06-02 mitigation)"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-12"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 06 Plan 01: Mayor Delegation Summary

**One-liner:** Convoy-driven autonomous dispatch via `gt convoy stage --launch` — one call replaces N per-plan `gt sling` calls, daemon handles wave sequencing.

## What Was Built

Two new bash functions added to `lib/gastown.sh` (v2 convoy handoff path), and two targeted blocks rewritten in `~/.claude/get-shit-done/workflows/execute-phase.md` (step 2.5 and step 4).

### launch_convoy() — lib/gastown.sh

Stages and launches a GSD phase convoy in one atomic call:

```bash
launch_convoy "06" "mayor-delegation" "gt-abc gt-def gt-ghi"
# → calls: gt convoy stage "GSD Phase 06: mayor-delegation" gt-abc gt-def gt-ghi --launch --json
# → returns: "hq-cv-xxxxx"
```

- Converts space-separated bead IDs to array, validates count > 0 (T-06-04 mitigation)
- Runs from `GT_TOWN_DIR` with `PATH` including `~/go/bin` (same pattern as existing functions)
- Parses `convoy_id` from JSON response via python3 with try/except error handling
- Returns 1 on any failure; outputs convoy_id on stdout

### poll_convoy_status() — lib/gastown.sh

Polls `gt convoy status <id> --json` until status=closed or timeout:

```bash
poll_convoy_status "hq-cv-xxxxx" 60 7200
# → emits: "CONVOY_POLLING: convoy=hq-cv-xxxxx status=open completed=2/3 (elapsed 60s)"
# → emits: "CONVOY_DONE: convoy hq-cv-xxxxx closed (3/3 beads)" on completion
# → emits: "CONVOY_TIMEOUT: waited 7200s..." on timeout (returns 1)
```

- Default interval: 60s (was 30s for per-bead polling — convoy is coarser grain)
- Default timeout: 7200s (2 hours — convoys span multiple plans; v1 was 1800s)
- Three distinct output tokens for caller pattern matching: CONVOY_DONE, CONVOY_TIMEOUT, CONVOY_POLLING

### execute-phase.md step 2.5 — v2 convoy handoff dispatch

**One-time detection block additions:**
- `GT_CONVOY_CAPABLE`: detects convoy stage support via `gt convoy stage --help` exit code
- `GT_ALL_BEAD_IDS`: array accumulating all bead IDs across all plans in the phase
- `GT_CONVOY_DISPATCHED`: tracks whether convoy launch succeeded

**Per-plan block change (v2 path):**
- Creates bead, adds to `GT_ALL_BEAD_IDS`, but does NOT sling
- v1 path (GT_CONVOY_CAPABLE=false): slings per-plan as before, unchanged

**After-plan-loop block (new):**
- Calls `launch_convoy()` once with all accumulated beads
- Updates gastown.json with convoy_id for all beads
- Sets `GT_CONVOY_DISPATCHED=true` to skip Task() spawning for all plans

### execute-phase.md step 4 — v2 convoy status polling

Added v2 convoy polling as the primary branch:
- `if GT_CONVOY_CAPABLE=true && GT_CONVOY_ID non-empty`: call `poll_convoy_status()`
- On CONVOY_DONE: iterate `GT_ALL_BEAD_IDS`, call `reconstruct_summary_from_bead` for each
- On CONVOY_TIMEOUT: write failure SUMMARY.md per plan (T-06-02 mitigation)

v1 wait_for_polecats block moved to `elif` branch — completely preserved, unchanged.

## Tasks

| Task | Status | Commit | Files |
|------|--------|--------|-------|
| 1: Add launch_convoy() and poll_convoy_status() | PASS | 0548701 | lib/gastown.sh |
| 2: Rewrite execute-phase.md step 2.5 and step 4 | PASS | 8f49b44 (gsd repo) | execute-phase.md |

## Verification Results

| Check | Result |
|-------|--------|
| `bash -n lib/gastown.sh` | PASS |
| `grep -c "^launch_convoy\|^poll_convoy_status" lib/gastown.sh` → 2 | PASS |
| `grep -c "^dispatch_plan_to_polecat\|^wait_for_polecats\|^create_phase_convoy" lib/gastown.sh` → 3 | PASS |
| convoy tokens in execute-phase.md ≥ 8 | PASS (28) |
| v1 fallback tokens in execute-phase.md ≥ 4 | PASS (14) |

## Decisions Made

- **Polling over push:** `gt convoy watch --nudge` requires GSD to have a gastown agent identity (tmux session). GSD is a bash/Node process — polling `gt convoy status --json` is simpler and more robust for Phase 6.
- **Feature flag via --help exit code:** `gt convoy stage --help` is the least intrusive capability check. No dry-run needed; help text availability is a reliable proxy for command support.
- **Preserve v1 in full:** All v1 functions remain in gastown.sh and execute-phase.md. The `elif` structure in step 4 means v1 and v2 paths are mutually exclusive and independently testable.
- **2-hour convoy timeout vs 30-min per-bead:** Convoys span multiple plans with wave sequencing; 30 minutes is insufficient. 7200s (2 hours) matches the research recommendation; configurable via `GASTOWN_POLL_TIMEOUT`.

## Deviations from Plan

None — plan executed exactly as written. The plan's pseudocode was used verbatim where provided. Minor addition: the CONVOY_TIMEOUT failure path in step 4 writes per-plan failure SUMMARY.md files (T-06-02 threat model mitigation — was specified in the threat model, implemented as written).

## Known Stubs

None. Both functions are complete implementations. execute-phase.md blocks are wired to the actual function calls.

## Threat Flags

No new network endpoints, auth paths, or trust boundaries introduced beyond those documented in the plan's threat model.

## Self-Check: PASSED

- `/Users/laul_pogan/Source/gsd-town/lib/gastown.sh` — exists, passes `bash -n`, contains both new functions
- `/Users/laul_pogan/.claude/get-shit-done/workflows/execute-phase.md` — modified, contains all required tokens
- Commit `0548701` in gsd-town repo — verified
- Commit `8f49b44` in get-shit-done repo — verified
