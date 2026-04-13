# Requirements: GSD-Town v2.0 — Gastown Drives

**Defined:** 2026-04-13
**Core Value:** GSD navigates, gastown drives — each system does what it's best at

## v2.0 Requirements

### Mayor Delegation

- [x] **MAYOR-01**: Mayor receives a convoy of beads and dispatches polecats autonomously
- [x] **MAYOR-02**: execute-phase.md delegates to Mayor via convoy handoff (replaces per-plan gt sling)
- [x] **MAYOR-03**: Mayor signals GSD orchestrator on convoy completion (replaces polling loop)

### Witness Integration

- [ ] **WITNESS-01**: GSD subscribes to Witness events for real-time stall/crash detection
- [ ] **WITNESS-02**: Witness-detected failures auto-record as GSD failed plans

### Refinery Merging

- [ ] **REFINERY-01**: Polecat branches submit to Refinery merge queue (replaces GSD worktree merge)
- [ ] **REFINERY-02**: GSD orchestrator waits for Refinery merge confirmation before verification

### Beads as Truth

- [ ] **BEADS-01**: Beads are source of truth for work status; STATE.md is a generated view
- [ ] **BEADS-02**: GSD verifier reads polecat results directly from beads (no SUMMARY.md round-trip)
- [ ] **BEADS-03**: Phase completion derived from convoy status (all beads closed = phase done)

### Seance Continuity

- [ ] **SEANCE-01**: Polecats auto-query Seance on resume for prior session decisions/context
- [ ] **SEANCE-02**: Failed polecat re-dispatch includes full Seance history from predecessor

## Future Requirements

- **FED-01**: Wasteland federation for cross-machine dispatch
- **MULTI-01**: Multi-rig dispatch — route plans to specialized rigs by type
- **DASH-01**: Convoy progress in GSD /gsd-progress output

## Out of Scope

| Feature | Reason |
|---------|--------|
| Replace GSD planning | Mayor dispatches, GSD plans — roles are clear |
| Replace GSD verification | GSD verifier is goal-backward; gastown has no equivalent |
| Wasteland federation | v3 — single-town must be solid first |
| GUI/dashboard | CLI-first; gastown dashboard exists for visual monitoring |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MAYOR-01 | Phase 6 | Complete |
| MAYOR-02 | Phase 6 | Complete |
| MAYOR-03 | Phase 6 | Complete |
| WITNESS-01 | Phase 7 | Pending |
| WITNESS-02 | Phase 7 | Pending |
| REFINERY-01 | Phase 8 | Pending |
| REFINERY-02 | Phase 8 | Pending |
| BEADS-01 | Phase 9 | Pending |
| BEADS-02 | Phase 9 | Pending |
| BEADS-03 | Phase 9 | Pending |
| SEANCE-01 | Phase 10 | Pending |
| SEANCE-02 | Phase 10 | Pending |

**Coverage:**
- v2.0 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-04-13*
