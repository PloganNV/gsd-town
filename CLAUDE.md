# GSD-Town

## What This Is

GSD-Town adds multi-agent parallel execution to GSD projects via Gas Town. Instead of running plans one at a time with Task() agents, it dispatches polecats (worker agents) — each with its own tmux session and git worktree.

## Quick Setup

```bash
# Install globally (from this repo)
cd ~/Source/gsd-town && npm install -g .

# Set up gastown for your project
cd /path/to/your/project
gsd-town setup
```

After setup, `/gsd-execute-phase` automatically detects gastown and dispatches polecats. No config changes needed.

## How It Works

When you run `/gsd-execute-phase`, the wired-in gastown dispatch block (execute-phase.md step 2.5) does this:

1. Sources `~/.claude/get-shit-done/bin/lib/gastown.sh` (18 functions)
2. Calls `detect_gastown()` — checks for gt binary + running daemon
3. If gastown available: creates a bead per plan (`bd create`), a convoy per phase (`gt convoy create`), dispatches polecats (`gt sling`)
4. Polls `gt polecat list --json` every 30s until all polecats complete
5. Reconstructs SUMMARY.md from bead notes (polecats write results before `gt done`)
6. Falls back to normal Task() execution if gastown is unavailable

## Key Commands

```bash
gsd-town setup                    # Install deps, create town, register rig
gsd-town status                   # Check if gastown is detected and running
gsd-town teardown                 # Stop daemon (data preserved)
gsd-town teardown --remove-data   # Stop daemon AND delete ~/.gsd-town/
gsd-town path                     # Print gastown.sh path for manual sourcing
```

## Configuration

Set in your project's `.planning/config.json`:

| Key | Default | Values |
|-----|---------|--------|
| `workflow.use_gastown` | `"auto"` | `"auto"` (detect), `true` (require), `false` (disable) |

```bash
# Disable gastown dispatch for this project
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.use_gastown false

# Re-enable
node ~/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.use_gastown auto
```

## Architecture

```
~/.gsd-town/                    # Managed town (created by gsd-town setup)
  mayor/rigs.json               # Registered project rigs
  gastown/                      # Default rig
    crew/<username>/            # Your crew workspace
    polecats/                   # Active polecat sessions

~/Source/gsd-town/              # This repo — the npm package
  lib/gastown.sh                # 18 dispatch functions (core)
  lib/auto-setup.sh             # 3 town lifecycle functions
  bin/gsd-town.js               # CLI entry point
  bin/postinstall.js             # Install hook (patches execute-phase.md)
  skills/gsd-town-setup/        # GSD skill for /gsd-town-setup

~/.claude/get-shit-done/
  bin/lib/gastown.sh             # Installed copy (symlinked or copied by postinstall)
  workflows/execute-phase.md     # Patched with gastown dispatch block
  bin/lib/config.cjs             # Has workflow.use_gastown in VALID_CONFIG_KEYS
  bin/lib/profile-output.cjs     # Has generateGastownSection() for CLAUDE.md
```

## Gastown Functions Reference (lib/gastown.sh)

### Detection & Helpers
- `detect_gastown()` — returns "true"/"false" based on gt in PATH + daemon running
- `gt_cmd(args...)` — runs gt from town root with correct PATH
- `bd_cmd(args...)` — runs bd from rig dir with correct PATH

### Dispatch
- `create_plan_bead(phase, plan, objective, notes)` — creates bead in rig's beads DB
- `create_phase_convoy(phase, name, first_bead)` — creates convoy for phase tracking
- `add_bead_to_convoy(convoy_id, bead_id)` — adds bead to existing convoy
- `dispatch_plan_to_polecat(bead_id, convoy_id)` — dispatches via gt sling
- `format_plan_notes(plan_path, phase, plan, objective, criteria, tasks, [convoy], [bead], [is_resume])` — creates bead notes for polecat prime

### Feedback
- `wait_for_polecats(bead_ids, phase_dir, project_dir, interval, timeout)` — polls until all done/failed
- `reconstruct_summary_from_bead(bead_id, output_path)` — reads bead notes, writes SUMMARY.md
- `write_results_to_bead(bead_id, content)` — writes SUMMARY content to bead notes
- `store_bead_mapping(project_dir, phase, plan, bead, convoy, objective)` — persists to gastown.json
- `check_polecat_state(bead_id)` — returns polecat state for a bead

### Resilience
- `check_escalation_status(bead_id)` — checks if bead has been escalated
- `check_capacity()` — reads scheduler.max_polecats, returns "ok"/"full"
- `queue_or_dispatch(bead_id, convoy_id, interval, max_wait)` — capacity-aware dispatch
- `resolve_plan_from_bead(bead_id, project_dir)` — looks up plan from gastown.json registry
- `seance_context_block(bead_id)` — generates Seance context for resumed polecats

## Important Notes

- **gt commands must run from town root** (`~/.gsd-town/` or `~/gt/`). The helper functions handle this.
- **bd commands must run from rig dir** (`~/.gsd-town/gastown/mayor/rig/`) for correct bead prefix routing.
- **bd is at `~/go/bin/bd`** — not in system PATH. Functions use absolute path.
- **gt hooks sync** writes only `.claude/settings.json` — it does NOT touch CLAUDE.md files. Safe.
- **Polecats write results to bead notes BEFORE calling `gt done`** — this is how results survive worktree teardown.

## Gastown Fork

Two fix branches are PR-ready at `laulpogan/gastown`:
- `fix/3603-gt-done-preflight` — pre-flight push/PR enforcement for gt done
- `fix/3622-convoy-event-uuid` — UUID regression test for convoy event poller

## Troubleshooting

```bash
# Check if daemon is running
cd ~/.gsd-town && gt daemon status

# Check if rig is registered
cd ~/.gsd-town && gt rig list

# Check active polecats
cd ~/.gsd-town && gt polecat list gastown --json

# Restart daemon
cd ~/.gsd-town && gt down && gt up

# Full reset
gsd-town teardown --remove-data && gsd-town setup
```

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work
