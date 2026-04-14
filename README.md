# GSD-Town

[![Tests](https://github.com/laulpogan/gsd-town/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/laulpogan/gsd-town/actions/workflows/test.yml)

**Multi-agent parallel execution for GSD via Gas Town**

GSD-Town is a portable plugin that adds multi-agent execution to any [GSD](https://github.com/get-shit-done) project via [Gas Town](https://github.com/gastownhall/gastown). It spins up and manages its own town workspace — no pre-existing gastown installation required. Run `/gsd-execute-phase` and it automatically dispatches polecats (worker agents) instead of single-agent execution.

Each polecat gets its own tmux session and git worktree — true process-isolated parallel execution with crash recovery.

## Quickstart

```bash
# Install GSD-Town globally
npm install -g gsd-town

# Set up gastown for your project (auto-installs dependencies)
cd your-project
gsd-town setup

# That's it. Now when you run:
/gsd-execute-phase 1

# ...GSD dispatches polecats instead of inline Task() agents
```

## What It Does

```
Without GSD-Town                    With GSD-Town
================                    =============

/gsd-execute-phase                  /gsd-execute-phase
       |                                   |
  [Task() agent]                    [detect gastown]
  [single context]                         |
  [one at a time]               +----------+----------+
       |                        |          |          |
   [plan 1]                 [polecat]  [polecat]  [polecat]
       |                   [plan 1]   [plan 2]   [plan 3]
   [plan 2]                 [tmux]     [tmux]     [tmux]
       |                   [worktree] [worktree] [worktree]
   [plan 3]                     |          |          |
       |                        +----------+----------+
   [verify]                            |
                                   [verify]
```

## Architecture

```
+------------------+     +------------------+     +------------------+
|    GSD           |     |   GSD-Town       |     |   Gas Town       |
|                  |     |                  |     |                  |
| execute-phase.md |---->| gastown.sh       |---->| gt sling         |
| (step 2.5)       |     | (18 functions)   |     | (polecat dispatch)|
|                  |     |                  |     |                  |
| verify-phase     |<----| wait_for_polecats|<----| gt polecat list  |
| (reads SUMMARY)  |     | reconstruct_     |     | bd show --json   |
|                  |     | summary_from_bead|     |                  |
+------------------+     +------------------+     +------------------+
                                |
                          +-----+------+
                          |            |
                    auto-setup.sh  gsd-town CLI
                    (3 functions)  (setup/status/
                                   teardown)
```

### Data Flow

1. **Dispatch:** GSD creates a bead per plan (`bd create`) and a convoy per phase (`gt convoy create`)
2. **Sling:** Each plan dispatches a polecat via `gt sling <bead-id> <rig>`
3. **Execute:** Polecat receives plan context at prime time from bead notes
4. **Result:** Polecat writes results to bead notes before `gt done`
5. **Collect:** GSD polls polecat status, reconstructs SUMMARY.md from bead notes
6. **Verify:** GSD verifier reads SUMMARY.md and gates the phase as normal

### Resilience

- **Stall detection:** Polls Witness status — dead polecats surface as failed plans
- **Escalation:** `gt escalate` from polecat surfaces to GSD verification
- **Capacity governor:** Respects `scheduler.max_polecats` — queues dispatch when at limit
- **Seance:** Resumed polecats receive prior session context automatically

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `workflow.use_gastown` | `"auto"` | `"auto"` = detect and dispatch; `false` = disable; `true` = require |
| `scheduler.max_polecats` | unlimited | Max concurrent polecats (gastown setting) |
| `workflow.gsd_town_root` | `~/.gsd-town` | Managed town location |

Set via GSD config:
```bash
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.use_gastown auto
```

## CLI Reference

```bash
gsd-town setup              # Install deps, create town, register rig
gsd-town setup --project-name myapp --project-path /path/to/project
gsd-town status              # Show town status and detection result
gsd-town teardown            # Stop daemon (preserves data)
gsd-town teardown --remove-data  # Stop daemon AND delete ~/.gsd-town
gsd-town path                # Print gastown.sh path for sourcing
gsd-town version             # Print version
```

## GSD Skill

After install, `/gsd-town-setup` is available as a GSD skill:

```
/gsd-town-setup
```

This runs the full setup flow interactively within Claude Code.

## Requirements

- **Node.js** 18+
- **macOS** (primary) or Linux
- **GSD** (Get Shit Done) plugin system installed

The following are auto-installed by `gsd-town setup` if missing:
- Go 1.25+
- Dolt
- tmux
- beads (bd)
- gt (Gas Town CLI, built from source)

## How It Works

GSD-Town manages its own Gas Town workspace at `~/.gsd-town/` (separate from any personal `~/gt/` town). On first dispatch:

1. Checks for dependencies (installs missing ones on macOS)
2. Creates a managed town with git tracking
3. Starts the gastown daemon (manages Dolt on port 3307)
4. Registers your project as a rig
5. Creates a crew workspace for your user

Subsequent dispatches reuse the existing town. The daemon stays running between sessions.

## Gastown Fork

GSD-Town includes critical bug fixes contributed upstream:

- **#3603:** `gt done` pre-flight checks — enforces commit/push/PR before marking beads complete
- **#3622:** Convoy event poller UUID type fix — prevents 5s error spam

Fork: [laulpogan/gastown](https://github.com/laulpogan/gastown)

## Versioning

GSD-Town uses [Semantic Versioning](https://semver.org/).

| Phase | Policy |
|-------|--------|
| Pre-1.0 (`0.x.y`) | Minor bumps (`0.x`) **may break the public API**. Patch bumps (`0.x.y`) are backward-compatible. |
| Post-1.0 (`1.x.y+`) | Strict semver — breaking changes only on major bumps. |

Breaking changes are documented in [CHANGELOG.md](./CHANGELOG.md).

---

## Public API

Functions intended for external use (scripts, GSD workflows, CI). Internal helpers are prefixed with `_` and subject to change without notice.

### gastown.sh

Source: `lib/gastown.sh` (installed to `~/.claude/get-shit-done/bin/lib/gastown.sh`)

#### Public

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_gastown` | `detect_gastown` | Returns `"true"` if gastown is available and should be used; `"false"` otherwise. Reads `workflow.use_gastown` config flag. |
| `gt_cmd` | `gt_cmd` | Returns the `gt` binary path (PATH or `~/.local/bin/gt` fallback). Use in subshells: `"$(gt_cmd)" ...` |
| `bd_cmd` | `bd_cmd` | Returns the `bd` binary path (always absolute — `~/go/bin/bd`). |
| `create_plan_bead` | `create_plan_bead <phase> <plan> <objective> <notes>` | Creates one bead in the rig database for a GSD plan. Outputs bead ID on stdout. |
| `create_phase_convoy` | `create_phase_convoy <phase> <name> <first_bead_id>` | Creates a convoy for phase tracking. Outputs convoy ID on stdout. |
| `add_bead_to_convoy` | `add_bead_to_convoy <convoy_id> <bead_id>` | Adds a bead to an existing convoy. Fire-and-forget (failure non-fatal). |
| `dispatch_plan_to_polecat` | `dispatch_plan_to_polecat <bead_id> <convoy_id>` | Dispatches a polecat via `gt sling`. |
| `format_plan_notes` | `format_plan_notes <plan_path> <phase> <plan> <objective> <criteria> <tasks> [convoy] [bead] [is_resume]` | Formats bead notes block that polecats read at prime time. |
| `wait_for_polecats` | `wait_for_polecats <bead_ids> <phase_dir> <project_dir> <interval> <timeout>` | Polls polecat status until all complete or timeout. |
| `reconstruct_summary_from_bead` | `reconstruct_summary_from_bead <bead_id> <output_path>` | Reads bead notes, writes `SUMMARY.md` to `output_path`. |
| `write_results_to_bead` | `write_results_to_bead <bead_id> <content>` | Writes SUMMARY content to bead notes (called by executor polecats before `gt done`). |
| `store_bead_mapping` | `store_bead_mapping <project_dir> <phase> <plan> <bead> <convoy> <objective>` | Persists phase/plan/bead/convoy mapping to `.planning/gastown.json`. |
| `check_polecat_state` | `check_polecat_state <bead_id>` | Returns polecat state string: `working`, `idle`, `done`, `stuck`, `stalled`, or `unknown`. |
| `check_escalation_status` | `check_escalation_status <bead_id>` | Returns `"escalated"` if bead has been escalated, `"normal"` otherwise. |
| `check_capacity` | `check_capacity` | Returns `"ok"` if under `scheduler.max_polecats` limit, `"full"` if at limit. |
| `queue_or_dispatch` | `queue_or_dispatch <bead_id> <convoy_id> <interval> <max_wait>` | Capacity-aware dispatch — waits for a slot before calling `dispatch_plan_to_polecat`. |
| `resolve_plan_from_bead` | `resolve_plan_from_bead <bead_id> <project_dir>` | Looks up plan path from `.planning/gastown.json` by bead ID. |
| `seance_context_block` | `seance_context_block <bead_id>` | Generates Seance context snippet for resumed polecats (embedded in bead notes). |

---

### auto-setup.sh

Source: `lib/auto-setup.sh`

#### Public

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_town` | `detect_town` | Finds or starts an existing gastown town. Searches `~/.gsd-town`, `~/gt`, `$GT_TOWN_ROOT`. Outputs town path on success (exit 0), nothing on failure (exit 1). |
| `check_and_install_deps` | `check_and_install_deps` | Checks for all GSD-Town dependencies (go, dolt, tmux, bd, gt); auto-installs missing ones on macOS via Homebrew. Prints install instructions on Linux (no auto-install). Returns 0 if all deps present. |
| `bootstrap_town` | `bootstrap_town <project_dir> <rig_name>` | Creates managed town at `~/.gsd-town`, starts daemon, registers project as rig, adds crew member. Idempotent. |

#### Internal

| Function | Notes |
|----------|-------|
| `_gsd_gt_cmd` | Resolves `gt` binary path for use within this module. Use `gt_cmd()` from `gastown.sh` instead. |
| `_ensure_dep` | Single-dep check+install helper; called by `check_and_install_deps`. |

---

### bead-state.sh

Source: `lib/bead-state.sh`

#### Public

| Function | Signature | Description |
|----------|-----------|-------------|
| `generate_state_from_beads` | `generate_state_from_beads <project_dir>` | Reads `.planning/gastown.json`, queries all beads, regenerates `STATE.md`. Implements BEADS-01. |
| `read_plan_result_from_bead` | `read_plan_result_from_bead <bead_id>` | Returns SUMMARY.md-equivalent markdown from bead notes on stdout. Implements BEADS-02. |
| `check_phase_completion_from_convoy` | `check_phase_completion_from_convoy <convoy_id>` | Returns `"complete"`, `"in-progress"`, or `"failed"` by counting child bead statuses. Implements BEADS-03. |
| `sync_requirements_from_beads` | `sync_requirements_from_beads <project_dir>` | Updates `REQUIREMENTS.md` checkboxes based on closed bead status. |

#### Internal

| Function | Notes |
|----------|-------|
| `_bs_bd_show` | Wraps `bd show --json`, normalizes array response. |
| `_bs_bd_list` | Wraps `bd list --json --flat` with extra filter args. |
| `_bs_load_registry` | Reads `.planning/gastown.json` or returns `{}`. |

---

### seance.sh

Source: `lib/seance.sh`

#### Public

| Function | Signature | Description |
|----------|-----------|-------------|
| `get_seance_predecessors` | `get_seance_predecessors <bead_id>` | Returns newline-delimited session IDs for prior polecat sessions on this bead. Scans `.events.jsonl`; falls back to `gt seance --role polecat`. |
| `build_seance_context` | `build_seance_context <bead_id>` | Queries each predecessor via `gt seance --talk` and returns a markdown context block. Slow — call only on re-dispatch. |
| `inject_seance_into_notes` | `inject_seance_into_notes <bead_id> <seance_context>` | Appends Seance context block to existing bead notes via `bd update --notes`. Call before re-dispatching a failed polecat. |

#### Internal

| Function | Notes |
|----------|-------|
| `_gt_seance_cmd` | Resolves `gt` binary path within seance.sh scope. |

---

## License

MIT
