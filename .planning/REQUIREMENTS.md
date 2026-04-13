# Requirements: GSD-Town

**Defined:** 2026-04-13
**Core Value:** Any GSD project gets multi-agent parallel execution with zero configuration

## v1 Requirements

### Fork and Fixes

- [ ] **FORK-01**: Gastown forked with upstream tracking; critical fixes applied
- [ ] **FORK-02**: `gt done` enforces commit/push/PR pre-flight checks before marking bead complete
- [ ] **FORK-03**: Convoy event poller scans `events.id` as string (CHAR(36) UUID), not int64

### Packaging

- [ ] **PKG-01**: GSD-Town npm package exports all dispatch functions as importable module
- [ ] **PKG-02**: GSD skill `/gsd-town-setup` configures any project for gastown dispatch
- [ ] **PKG-03**: execute-phase.md gastown dispatch installable as hook or patch

### Auto-Setup

- [ ] **AUTO-01**: GSD-Town spins up its own managed town workspace (not user's ~/gt/)
- [ ] **AUTO-02**: Auto-install all gastown dependencies if not present (go, dolt, beads, tmux, gt)
- [ ] **AUTO-03**: Auto-create rig + crew for current project within managed town on first dispatch
- [ ] **AUTO-04**: Zero-config dispatch — `workflow.use_gastown: auto` bootstraps everything on first use
- [ ] **AUTO-05**: Town lifecycle management — start daemon on dispatch, stop on idle, clean up on uninstall

### Resilience

- [ ] **RESIL-01**: Stall detection — GSD polls Witness status, surfaces dead polecats as failed plans
- [ ] **RESIL-02**: Escalation routing — `gt escalate` from polecat surfaces to GSD verification
- [ ] **RESIL-03**: Capacity-governed dispatch — respects `scheduler.max_polecats` config
- [ ] **RESIL-04**: Seance integration — resumed polecats get prior session context

### Polish

- [ ] **POLISH-01**: README with quickstart, architecture diagram, and config reference
- [ ] **POLISH-02**: Example project demonstrating GSD-Town end-to-end

## v2 Requirements

### Advanced Features

- **ADV-01**: Multi-rig support — dispatch to different rigs based on plan type
- **ADV-02**: Convoy progress dashboard in GSD `/gsd-progress` output
- **ADV-03**: Automatic upstream sync — merge gastown upstream changes into fork

## Out of Scope

| Feature | Reason |
|---------|--------|
| Wasteland federation | Cross-town coordination too complex for v1 |
| Windows support | No Windows test environment; macOS/Linux first |
| GUI/dashboard | CLI-first; gastown has its own dashboard |
| GSD core modifications | Plugin architecture — GSD stays independent |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FORK-01 | Phase 1 | Pending |
| FORK-02 | Phase 1 | Pending |
| FORK-03 | Phase 1 | Pending |
| PKG-01 | Phase 2 | Pending |
| PKG-02 | Phase 2 | Pending |
| PKG-03 | Phase 2 | Pending |
| AUTO-01 | Phase 3 | Pending |
| AUTO-02 | Phase 3 | Pending |
| AUTO-03 | Phase 3 | Pending |
| AUTO-04 | Phase 3 | Pending |
| AUTO-05 | Phase 3 | Pending |
| RESIL-01 | Phase 4 | Pending |
| RESIL-02 | Phase 4 | Pending |
| RESIL-03 | Phase 4 | Pending |
| RESIL-04 | Phase 4 | Pending |
| POLISH-01 | Phase 5 | Pending |
| POLISH-02 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

---
*Requirements defined: 2026-04-13*
*Last updated: 2026-04-13 after initial definition*
