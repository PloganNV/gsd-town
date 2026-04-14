# GSD-Town

## What This Is

GSD-Town is a GSD plugin that replaces single-agent execution with multi-agent parallel dispatch via Gas Town. GSD handles planning and verification; gastown handles execution, monitoring, merging, and persistence. Install it alongside GSD and your `/gsd-execute-phase` dispatches polecats instead of Task() agents — each with its own tmux session, worktree, and crash recovery.

Gastown is vendored as a submodule. GSD is a peer dependency (must be installed). As v2 matures, gsd-town becomes increasingly self-sufficient — a natural path to independence if needed, but no rush to get there.

## Core Value

Multi-agent parallel execution for any GSD project. Polecats do the work; gsd-town ensures they do the right work via gastown's convoy/monitoring/merge infrastructure.

## Architecture

```
gsd-town (this repo)
├── Planning    — AI-generated phases, plans, discuss pipeline (inspired by GSD)
├── Dispatch    — convoy-driven polecat execution (gastown native)
├── Monitoring  — Witness/Deacon event subscription (gastown native)
├── Merging     — Refinery merge queue (gastown native)
├── Persistence — Beads as source of truth (gastown native)
├── Verification — Goal-backward checking (reimplemented from GSD concepts)
└── vendor/gastown — gastown fork (submodule, only runtime dependency)
```

## Requirements

### Validated

v1.0 prototype (GSD plugin era — concepts proven, being reimplemented):
- [x] Polecat dispatch per plan via gt sling
- [x] Convoy tracking per phase
- [x] Bead-based result persistence
- [x] Stall detection, escalation, capacity governor
- [x] Auto-setup (town creation, rig registration, dep install)

### Active

v2.0 — standalone product:
- [ ] **CORE-01**: Native project initialization (replace /gsd-new-project)
- [ ] **CORE-02**: Native phase/plan structure (own format, not .planning/ GSD layout)
- [ ] **CORE-03**: Native discuss→plan→execute pipeline (no GSD skill dependencies)
- [ ] **CORE-04**: Convoy-driven dispatch (gt convoy stage --launch, daemon auto-waves)
- [ ] **CORE-05**: Convoy status polling for completion (replaces per-polecat polling)
- [ ] **CORE-06**: Witness event subscription for stall/crash detection
- [ ] **CORE-07**: Refinery merge queue integration (replaces worktree merge)
- [ ] **CORE-08**: Beads as work state source of truth (replaces STATE.md)
- [ ] **CORE-09**: Goal-backward verification reading from beads
- [ ] **CORE-10**: Seance continuity for resumed polecats
- [ ] **CLI-01**: `gsd-town init` — initialize project with phases
- [ ] **CLI-02**: `gsd-town plan <phase>` — AI-generate execution plans
- [ ] **CLI-03**: `gsd-town run <phase>` — dispatch convoy, monitor, verify
- [ ] **CLI-04**: `gsd-town status` — project progress from beads
- [ ] **CLI-05**: `gsd-town setup` — install deps, create town, register rig (existing, keep)

### Out of Scope

- GSD plugin compatibility — we're independent now
- Wasteland federation — v3
- GUI/dashboard — CLI-first
- Custom agent runtimes — gastown handles this

## Current Milestone: v3.0 Long-Term Maintenance

**Goal:** Harden gsd-town for sustained use — survive GSD updates, catch regressions in CI, document API contracts, and test against pinned gastown.

**Target features:**
- `gsd-town doctor` — detect and repair missing GSD patches (GSD updates wipe them)
- GitHub Actions CI — run tests on every push/PR
- CHANGELOG.md + semver policy — public API contract
- Pinned gastown smoke test — catch upstream drift

## Context

- Gastown vendored at vendor/gastown (submodule, laulpogan/gastown fork)
- GSD's good ideas reimplemented natively: phases, plans, verification, discuss pipeline
- No patches to external files — gsd-town owns all its code
- The 18 bash dispatch functions (gastown.sh) carry forward as the execution layer
- auto-setup.sh carries forward for dependency management

## Constraints

- **Single dependency**: gastown (vendored submodule) is the only runtime dep
- **No GSD dependency**: must work without GSD installed
- **Platform**: macOS primary, Linux secondary
- **Claude Code compatible**: works as a Claude Code project but doesn't require it

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Go independent from GSD | Patching external files is fragile; own the full stack | -- Pending |
| Gastown as submodule | Single vendored dependency, pinned version | ✓ Good |
| Reimplement GSD concepts natively | Own the planning layer, purpose-built for convoy model | -- Pending |
| Keep bash dispatch functions | 18 functions proven in v1; wrap in CLI, don't rewrite | -- Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-04-13 after v2.0 independence pivot*
