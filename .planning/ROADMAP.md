# Roadmap: GSD-Town

## Overview

GSD-Town adds multi-agent execution to any GSD project via Gas Town. The build sequence is strictly sequential: fix the upstream bugs first (can't build on broken), then package the integration, then automate setup, then harden for production, then document for distribution. Each phase delivers a coherent capability before the next begins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Fork + Critical Fixes** - Fork gastown and apply the two blocking bugs (gt done enforcement, convoy UUID)
- [ ] **Phase 2: npm Package** - Ship GSD-Town as an installable npm package with skill registration and execute-phase hook
- [x] **Phase 3: Auto-Setup** - Zero-config detection, dependency install, and town creation on first use (completed 2026-04-13)
- [ ] **Phase 4: Resilience** - Stall detection, escalation routing, capacity governance, and session resume
- [ ] **Phase 5: Polish** - README quickstart, architecture diagram, config reference, and example project

## Phase Details

### Phase 1: Fork + Critical Fixes
**Goal**: A working gastown fork exists with critical bugs fixed, making polecat dispatch production-safe
**Depends on**: Nothing (first phase)
**Requirements**: FORK-01, FORK-02, FORK-03
**Success Criteria** (what must be TRUE):
  1. A GSD-Town fork of gastown exists with upstream tracking configured
  2. Running `gt done` without a committed/pushed/PR'd branch is rejected with a clear error
  3. Convoy event polling correctly reads event UUIDs as strings (CHAR(36)), not int64 — no type mismatch panics
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Fork GitHub + configure remotes + UUID regression test (FORK-01, FORK-03)
- [x] 01-02-PLAN.md — gt done pre-flight push/PR enforcement (FORK-02)

### Phase 2: npm Package
**Goal**: GSD-Town is installable as an npm package that registers a GSD skill and wires execute-phase dispatch
**Depends on**: Phase 1
**Requirements**: PKG-01, PKG-02, PKG-03
**Success Criteria** (what must be TRUE):
  1. `npm install -g gsd-town` succeeds and puts gastown.sh dispatch functions on the PATH
  2. Running `/gsd-town-setup` in any project configures it for gastown dispatch
  3. execute-phase.md's gastown dispatch block is installable as a hook or patch with a single command
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — npm package scaffold + gastown.sh bundle + gsd-town CLI (PKG-01)
- [x] 02-02-PLAN.md — GSD skill /gsd-town-setup + execute-phase.md patch installer (PKG-02, PKG-03)

### Phase 3: Auto-Setup
**Goal**: A user can run `/gsd-execute-phase` in a fresh project and gastown is detected, installed, and configured with no manual steps
**Depends on**: Phase 2
**Requirements**: AUTO-01, AUTO-02, AUTO-03, AUTO-04, AUTO-05
**Success Criteria** (what must be TRUE):
  1. GSD-Town detects an existing town at `~/.gsd-town`, `~/gt/`, or `$GT_TOWN_ROOT` without prompting the user
  2. If gastown dependencies (go, dolt, beads, tmux, gt) are missing, they are installed automatically
  3. A new project gets a town, rig, and crew provisioned on first use without any manual `gt` commands
  4. Setting `workflow.use_gastown: auto` is the only config change needed to enable polecat dispatch
  5. Town lifecycle (daemon start/stop, teardown, npm uninstall cleanup) is fully managed
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — lib/auto-setup.sh: detect_town, check_and_install_deps, bootstrap_town (AUTO-01, AUTO-02, AUTO-03)
- [x] 03-02-PLAN.md — bin/gsd-town.js setup/teardown/status + preuninstall cleanup (AUTO-04, AUTO-05)

### Phase 4: Resilience
**Goal**: GSD-Town handles polecat failures, blockages, and capacity limits without human intervention or silent data loss
**Depends on**: Phase 3
**Requirements**: RESIL-01, RESIL-02, RESIL-03, RESIL-04
**Success Criteria** (what must be TRUE):
  1. A stalled or crashed polecat is detected by GSD within a configurable polling window and surfaced as a failed plan
  2. A polecat that runs `gt escalate` causes GSD to surface the blockage to the user for resolution
  3. Dispatch respects `scheduler.max_polecats` — new polecats are queued, not spawned, when at capacity
  4. A resumed polecat receives prior session context via Seance and continues rather than starting over
**Plans**: TBD

### Phase 5: Polish
**Goal**: GSD-Town is fully documented and demonstrable so a new user can get from zero to running polecats in under 10 minutes
**Depends on**: Phase 4
**Requirements**: POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):
  1. README contains a quickstart section (install → configure → run), an architecture diagram, and a config reference
  2. An example project exists that demonstrates a full GSD-Town dispatch cycle end-to-end
  3. A user following the README quickstart can dispatch their first polecat without reading source code
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Fork + Critical Fixes | 0/2 | Not started | - |
| 2. npm Package | 0/2 | Not started | - |
| 3. Auto-Setup | 2/2 | Complete   | 2026-04-13 |
| 4. Resilience | 0/TBD | Not started | - |
| 5. Polish | 0/TBD | Not started | - |
