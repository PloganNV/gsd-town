# GSD-Town

## What This Is

GSD-Town is a portable GSD plugin that adds multi-agent execution to any project via Gas Town. It spins up and manages its own town workspace — no pre-existing gastown installation required. Run `/gsd-execute-phase` and it automatically bootstraps a town, creates a rig for your project, and dispatches polecats (worker agents) instead of single-agent Task() calls. Each polecat gets its own tmux session and git worktree — true process-isolated parallel execution with crash recovery.

## Core Value

Any GSD project gets multi-agent parallel execution by running a single command — GSD-Town handles the entire gastown lifecycle (install, town creation, rig setup, dispatch, teardown).

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **FORK-01**: Fork gastown with critical bug fixes (gt done enforcement, convoy poller UUID)
- [ ] **FORK-02**: gt done pre-flight checks — commit/push/PR enforcement before marking bead complete
- [ ] **FORK-03**: Convoy event poller reads UUID as string, not int64
- [ ] **PKG-01**: GSD-Town npm package with gastown.sh functions as portable module
- [ ] **PKG-02**: GSD skill registration — /gsd-town-setup command for any project
- [ ] **PKG-03**: execute-phase.md integration as installable patch/hook
- [ ] **AUTO-01**: Auto-detect gastown town (~/gt/ or GT_TOWN_ROOT env)
- [ ] **AUTO-02**: Auto-install gastown if not present (brew/npm/go install)
- [ ] **AUTO-03**: Auto-create town + rig + crew for current project on first use
- [ ] **AUTO-04**: Zero-config dispatch — no manual gt commands needed
- [ ] **RESIL-01**: Stall detection — Witness monitors polecats, GSD knows when they die
- [ ] **RESIL-02**: Escalation routing — blocked polecat surfaces to GSD/user
- [ ] **RESIL-03**: Capacity-governed dispatch via Scheduler (max_polecats config)
- [ ] **RESIL-04**: Persistent context via Seance — resume interrupted polecat work
- [ ] **POLISH-01**: README with quickstart, architecture diagram, config reference
- [ ] **POLISH-02**: Example project showing GSD-Town in action

### Out of Scope

- Wasteland federation (cross-town coordination) — too complex for v1
- Custom gastown runtimes — use what gastown supports
- GUI/dashboard — CLI-first product
- Modifying GSD core — GSD-Town is a plugin, not a fork of GSD

## Context

- Built on top of Gas Town (gastownhall/gastown) — multi-agent workspace manager
- GSD is Get Shit Done — a Claude Code skill system for project planning and execution
- The integration was prototyped in /Users/laul_pogan/Source/gastown during v1.0 milestone
- 13 bash functions in gastown.sh handle detection, dispatch, polling, result feedback
- execute-phase.md has conditional gastown dispatch wired at step 2.5 and step 4
- Key insight: one polecat per GSD plan (not per task) — plans have sequential task deps

## Constraints

- **Platform**: macOS primary, Linux secondary. No Windows yet.
- **Dependencies**: Go 1.25+, Dolt, beads (bd), tmux, Node.js 18+
- **GSD compatibility**: Must not break GSD for non-gastown users (capability detection)
- **Gastown fork**: Minimal divergence from upstream — only critical fixes, PR everything back

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fork gastown for critical fixes | gt done and convoy poller bugs block production use | -- Pending |
| npm package distribution | GSD users already have Node.js; npm is the natural distribution | -- Pending |
| Plugin architecture (not GSD fork) | Keeps both projects independent; users opt-in | -- Pending |
| One polecat per plan | Tasks within a plan have sequential deps; splitting causes merge conflicts | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-13 after initialization*
