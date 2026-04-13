# Phase 6: Mayor Delegation (Convoy-Driven Dispatch) - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated from research findings

<domain>
## Phase Boundary

Replace execute-phase.md's per-plan `gt sling` dispatch with convoy-driven autonomous dispatch via `gt convoy stage --launch`. The daemon handles wave computation, polecat dispatch, and subsequent wave auto-advancement. GSD polls convoy status instead of individual polecat states.

Key correction from research: "Mayor delegation" is really "convoy delegation" — the Mayor is an LLM session, not a dispatch API. The convoy+daemon system IS the autonomous dispatch engine.

</domain>

<decisions>
## Implementation Decisions

### Dispatch Rewrite (MAYOR-01, MAYOR-02)
- Replace: execute-phase.md step 2.5 creates beads + calls gt sling per plan
- With: create beads → create convoy with all beads → `gt convoy stage --launch`
- `gt convoy stage --launch` validates DAG, computes waves, dispatches Wave 1 automatically
- Daemon's `check-convoy-completion` patrol dispatches subsequent waves as polecats finish
- GSD no longer needs to know about waves — gastown handles wave sequencing

### Completion Signal (MAYOR-03)
- Replace: wait_for_polecats() polling individual polecat states every 30s
- With: poll `gt convoy status <id> --json` until status="closed"
- Convoy closed = all beads closed = all plans done
- Simpler: one status check instead of N polecat checks
- Future: `gt convoy watch --nudge` for push notification (requires gastown agent identity)

### Backward Compatibility
- If `gt convoy stage --launch` is not available (older gastown): fall back to v1 per-plan sling
- Detection: check `gt convoy stage --help` exit code

### What Changes in execute-phase.md
- Step 2.5: create all beads first, then single convoy stage --launch (instead of per-plan sling loop)
- Step 4: poll convoy status (instead of per-polecat polling)
- Steps 5.5/5.6: skip worktree cleanup/merge (Refinery handles this in Phase 8)
- SUMMARY.md reconstruction: still read from beads (unchanged from v1)

### Claude's Discretion
- Error handling for convoy stage failures
- Convoy status polling interval (30s seems right)
- Whether to log wave progress from convoy status during polling

</decisions>

<code_context>
## Key Source Findings (from 06-RESEARCH.md)

- `gt convoy stage --launch --json` is the entry point — returns convoy ID and dispatched beads
- Convoy status: "staged" → "open" (after launch) → "closed" (all done)
- `gt convoy status <id> --json` returns structured status with bead states
- `notifyConvoyCompletion()` fires when convoy closes — but requires agent identity to receive
- Wave auto-dispatch handled by daemon patrol step `check-convoy-completion`
- `gt sling` bypasses Mayor entirely — goes direct to rig

### Files to Modify
- lib/gastown.sh: add launch_convoy(), poll_convoy_status() functions
- execute-phase.md step 2.5: rewrite dispatch block
- execute-phase.md step 4: rewrite polling block

</code_context>

<specifics>
No specific requirements beyond research findings.
</specifics>

<deferred>
- Push notifications via gt convoy watch --nudge (requires agent identity — Phase 10+)
</deferred>
