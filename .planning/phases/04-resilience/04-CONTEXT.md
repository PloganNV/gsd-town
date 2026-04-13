# Phase 4: Resilience - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous)

<domain>
## Phase Boundary

Add production-grade reliability to GSD-Town: stall detection (Witness polling), escalation routing (gt escalate surfaces to GSD), capacity-governed dispatch (scheduler.max_polecats), and Seance integration (resumed polecats get prior session context). These are additive on the proven dispatch+feedback loop from earlier phases.

</domain>

<decisions>
## Implementation Decisions

### Stall Detection (RESIL-01)
- GSD polls `gt polecat list --json` — if a polecat is in "stalled" or "stuck" state, surface as failed plan
- Witness already monitors polecats — GSD just needs to read the state
- Add to wait_for_polecats() in gastown.sh — already handles "stuck"/"stalled" states, just ensure proper SUMMARY.md failure write

### Escalation Routing (RESIL-02)
- Polecat calls `gt escalate` when blocked → creates escalation bead
- GSD needs to detect escalations during polling: check if bead has escalation status
- Surface to user as a checkpoint requiring human decision
- Use `bd show <bead-id> --json` to check for escalation field

### Capacity Governor (RESIL-03)
- Read `scheduler.max_polecats` from gastown config (town settings)
- Before dispatch: check current polecat count vs limit
- If at capacity: queue the dispatch, retry after polling interval
- Add to dispatch_plan_to_polecat() or as a wrapper

### Seance Integration (RESIL-04)
- When a polecat is resumed (not first dispatch): use `gt seance` to inject prior session context
- The polecat's CLAUDE.md/AGENTS.md should include Seance discovery instructions
- Add to format_plan_notes(): include seance query instruction if bead has prior events

### Claude's Discretion
- Exact queue implementation for capacity governor
- Seance context format for polecat prime
- Whether escalation creates a new GSD checkpoint or just logs

</decisions>

<code_context>
## Existing Code

- lib/gastown.sh: wait_for_polecats() already handles "stuck"/"stalled" → failure SUMMARY
- lib/gastown.sh: dispatch_plan_to_polecat() is the dispatch point for capacity checks
- lib/gastown.sh: format_plan_notes() creates polecat prime context
- lib/auto-setup.sh: town detection and lifecycle

</code_context>

<specifics>
No specific requirements.
</specifics>

<deferred>
None.
</deferred>
