# GSD-Town

## What This Is

GSD-Town is a deep integration between GSD (planning/verification) and Gas Town (execution/persistence/monitoring). GSD decides what to build; gastown handles how — dispatching polecats, monitoring health, merging code, persisting work state. Install it and `/gsd-execute-phase` delegates to the Mayor for multi-agent parallel execution with crash recovery.

## Core Value

GSD navigates, gastown drives — each system does what it's best at.

## Requirements

### Validated

v1.0 shipped (integration prototype):
- [x] **FORK-01**: Gastown forked with upstream tracking
- [x] **FORK-02**: gt done pre-flight checks
- [x] **FORK-03**: Convoy event poller UUID fix
- [x] **PKG-01**: npm package with dispatch functions
- [x] **PKG-02**: GSD skill /gsd-town-setup
- [x] **PKG-03**: execute-phase.md integration patch
- [x] **AUTO-01**: Town auto-detection
- [x] **AUTO-02**: Dependency auto-install
- [x] **AUTO-03**: Town+rig+crew auto-creation
- [x] **AUTO-04**: Zero-config dispatch
- [x] **RESIL-01**: Stall detection (polling)
- [x] **RESIL-02**: Escalation detection
- [x] **RESIL-03**: Capacity governor
- [x] **RESIL-04**: Seance context block
- [x] **POLISH-01**: README
- [x] **POLISH-02**: Example project

### Active

v2.0 — "GSD navigates, gastown drives":
- [ ] **MAYOR-01**: Mayor receives convoy of beads and orchestrates polecat dispatch (replaces execute-phase.md gt sling calls)
- [ ] **MAYOR-02**: execute-phase.md hands off to Mayor via `gt convoy dispatch` instead of calling gt sling per plan
- [ ] **MAYOR-03**: Mayor completion callback signals GSD orchestrator (replaces polling loop)
- [ ] **WITNESS-01**: Subscribe to Witness events for stall/crash detection (replaces 30s polling)
- [ ] **WITNESS-02**: Witness-detected failures automatically trigger GSD failed-plan recording
- [ ] **REFINERY-01**: Polecat branches submit to Refinery merge queue instead of GSD worktree merge
- [ ] **REFINERY-02**: GSD orchestrator waits for Refinery merge confirmation before verification
- [ ] **BEADS-01**: Beads become source of truth for work status (STATE.md generated from beads)
- [ ] **BEADS-02**: Verifier reads results directly from beads (no SUMMARY.md round-trip)
- [ ] **BEADS-03**: Phase completion derived from convoy completion (all beads closed)
- [ ] **SEANCE-01**: Polecats auto-query Seance on resume for prior session context
- [ ] **SEANCE-02**: Failed polecat re-dispatch includes full Seance history

### Out of Scope

- Wasteland federation — defer to v3
- Modifying GSD core planning pipeline — GSD-Town is a plugin
- Replacing GSD's verification with gastown's — GSD verifier is superior
- Mayor as project planner — Mayor dispatches, GSD plans

## Context

- v1.0 is the "backseat driving" integration — GSD calls gt CLI commands to puppet gastown from outside
- v2.0 inverts the control: GSD hands gastown a convoy and delegates execution entirely
- The key architectural shift: execute-phase.md stops calling gt sling/polling and instead sends a convoy to the Mayor
- Mayor already coordinates polecats, manages Witness, feeds Refinery — we just need to use it
- Beads persist work state in Dolt (SQL DB) — far more durable than STATE.md (markdown file)
- Refinery does Bors-style bisecting merge queue with CI gating — better than GSD's worktree merge

## Constraints

- **Backward compatible**: v1 CLI-driven dispatch must still work as fallback
- **Mayor protocol**: Need to understand how to programmatically hand work to the Mayor
- **Refinery integration**: Need to understand MR bead lifecycle for GSD's merge expectations
- **Platform**: macOS primary, Linux secondary

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One polecat per plan | Tasks within a plan have sequential deps | ✓ Good |
| v1: GSD puppets gastown via CLI | Fast to build, proved the concept | ✓ Served its purpose |
| v2: Mayor as execution orchestrator | Mayor already does this — stop reinventing | -- Pending |
| v2: Refinery for merges | Bors-style queue > worktree merge | -- Pending |
| v2: Beads as work state truth | Dolt DB > markdown file for durability | -- Pending |
| v2: Verifier reads beads directly | Eliminates SUMMARY.md round-trip | -- Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-13 after v2.0 milestone start*
