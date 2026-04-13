# Roadmap: GSD-Town

## Milestones

- ✅ **v1.0 Prototype** - Phases 1-5 (shipped 2026-04-13)
- 🚧 **v2.0 Gastown Drives** - Phases 6-10 (in progress)

## Phases

<details>
<summary>✅ v1.0 Prototype (Phases 1-5) - SHIPPED 2026-04-13</summary>

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
**Requirements**: AUTO-01, AUTO-02, AUTO-03, AUTO-04
**Success Criteria** (what must be TRUE):
  1. GSD-Town detects an existing town at `~/.gsd-town`, `~/gt/`, or `$GT_TOWN_ROOT` without prompting the user
  2. If gastown dependencies (go, dolt, beads, tmux, gt) are missing, they are installed automatically
  3. A new project gets a town, rig, and crew provisioned on first use without any manual `gt` commands
  4. Setting `workflow.use_gastown: auto` is the only config change needed to enable polecat dispatch
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — lib/auto-setup.sh: detect_town, check_and_install_deps, bootstrap_town (AUTO-01, AUTO-02, AUTO-03)
- [x] 03-02-PLAN.md — bin/gsd-town.js setup/teardown/status + zero-config dispatch (AUTO-04)

### Phase 4: Resilience
**Goal**: GSD-Town handles polecat failures, blockages, and capacity limits without human intervention or silent data loss
**Depends on**: Phase 3
**Requirements**: RESIL-01, RESIL-02, RESIL-03, RESIL-04
**Success Criteria** (what must be TRUE):
  1. A stalled or crashed polecat is detected by GSD within a configurable polling window and surfaced as a failed plan
  2. A polecat that runs `gt escalate` causes GSD to surface the blockage to the user for resolution
  3. Dispatch respects `scheduler.max_polecats` — new polecats are queued, not spawned, when at capacity
  4. A resumed polecat receives prior session context via Seance and continues rather than starting over
**Plans**: 1 plan

Plans:
- [x] 04-01-PLAN.md — Resilience enhancements: stall detection, escalation routing, capacity governor, Seance context (RESIL-01, RESIL-02, RESIL-03, RESIL-04)

### Phase 5: Polish
**Goal**: GSD-Town is fully documented and demonstrable so a new user can get from zero to running polecats in under 10 minutes
**Depends on**: Phase 4
**Requirements**: POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):
  1. README contains a quickstart section (install → configure → run), an architecture diagram, and a config reference
  2. An example project exists that demonstrates a full GSD-Town dispatch cycle end-to-end
  3. A user following the README quickstart can dispatch their first polecat without reading source code
**Plans**: 1 plan

Plans:
- [x] 05-01-PLAN.md — README + example project (POLISH-01, POLISH-02)

</details>

### 🚧 v2.0 Gastown Drives (In Progress)

**Milestone Goal:** GSD hands gastown a convoy and delegates execution entirely. Mayor orchestrates polecats, Witness monitors in real time, Refinery handles merges, Beads persist truth, Seance carries context across runs. GSD keeps planning and verification; gastown drives everything else.

#### Phase 6: Mayor Delegation
**Goal**: execute-phase.md hands a convoy to the Mayor and waits for a completion callback — no per-plan sling calls, no polling loop
**Depends on**: Phase 5
**Requirements**: MAYOR-01, MAYOR-02, MAYOR-03
**Success Criteria** (what must be TRUE):
  1. Running /gsd-execute-phase dispatches a single convoy to the Mayor rather than calling gt sling once per plan
  2. Mayor autonomously dispatches all polecats in the convoy without GSD orchestrating individual workers
  3. GSD orchestrator advances on Mayor completion callback — no 30-second polling loop

**Plans**: 1 plan

Plans:
- [x] 06-01-PLAN.md — Add launch_convoy() + poll_convoy_status() to gastown.sh; rewrite execute-phase.md dispatch (step 2.5) and polling (step 4) for convoy handoff (MAYOR-01, MAYOR-02, MAYOR-03)

#### Phase 7: Witness Integration
**Goal**: Real-time stall and crash detection via Witness event subscription replaces the 30-second polling loop
**Depends on**: Phase 6
**Requirements**: WITNESS-01, WITNESS-02
**Success Criteria** (what must be TRUE):
  1. GSD subscribes to Witness events and receives stall/crash signals in real time — no polling
  2. A Witness-detected polecat failure automatically records a GSD failed plan without user intervention

**Plans**: TBD

Plans:
- [ ] 07-01: Research Witness event subscription API + implement GSD subscriber + wire to failed-plan recorder

#### Phase 8: Refinery Merging
**Goal**: Polecat branches enter Refinery's Bors-style merge queue; GSD verification does not start until Refinery confirms merge
**Depends on**: Phase 7
**Requirements**: REFINERY-01, REFINERY-02
**Success Criteria** (what must be TRUE):
  1. On polecat completion, the branch is submitted to Refinery merge queue — GSD worktree merge no longer runs
  2. GSD orchestrator waits for a Refinery merge confirmation signal before invoking /gsd-verify-phase

**Plans**: TBD

Plans:
- [ ] 08-01: Research Refinery MR bead lifecycle + implement branch submission + confirmation signal handler

#### Phase 9: Beads as Truth
**Goal**: Dolt-backed beads replace STATE.md as the source of work state; verifier reads results directly from beads
**Depends on**: Phase 8
**Requirements**: BEADS-01, BEADS-02, BEADS-03
**Success Criteria** (what must be TRUE):
  1. STATE.md is generated from bead data — GSD does not write work state directly
  2. /gsd-verify-phase reads polecat results from beads — SUMMARY.md round-trip is eliminated
  3. Phase completion is determined by convoy status (all beads closed), not a GSD-side flag

**Plans**: TBD

Plans:
- [ ] 09-01: Implement STATE.md generation from beads + verifier bead reader + convoy-closed phase gate

#### Phase 10: Seance Continuity
**Goal**: Resumed and re-dispatched polecats automatically receive full prior session history from Seance
**Depends on**: Phase 9
**Requirements**: SEANCE-01, SEANCE-02
**Success Criteria** (what must be TRUE):
  1. A resumed polecat auto-queries Seance and receives prior session decisions without manual context passing
  2. A failed polecat re-dispatched to a new worker includes the full Seance history from its predecessor

**Plans**: TBD

Plans:
- [ ] 10-01: Auto-query Seance on polecat resume + include predecessor Seance history in re-dispatch payload

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8 → 9 → 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Fork + Critical Fixes | v1.0 | 2/2 | Complete | 2026-04-13 |
| 2. npm Package | v1.0 | 2/2 | Complete | 2026-04-13 |
| 3. Auto-Setup | v1.0 | 2/2 | Complete | 2026-04-13 |
| 4. Resilience | v1.0 | 1/1 | Complete | 2026-04-13 |
| 5. Polish | v1.0 | 1/1 | Complete | 2026-04-13 |
| 6. Mayor Delegation | v2.0 | 1/1 | Complete   | 2026-04-13 |
| 7. Witness Integration | v2.0 | 0/1 | Not started | - |
| 8. Refinery Merging | v2.0 | 0/1 | Not started | - |
| 9. Beads as Truth | v2.0 | 0/1 | Not started | - |
| 10. Seance Continuity | v2.0 | 0/1 | Not started | - |
