# GSD-Town

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

## License

MIT
