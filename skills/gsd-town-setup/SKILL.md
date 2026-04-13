# Skill: gsd-town-setup

**Command:** `/gsd-town-setup`
**Package:** gsd-town (npm)
**Purpose:** Configure any GSD project for gastown polecat dispatch

## When to Use

Run `/gsd-town-setup` in a GSD project to:
- Verify gastown dependencies are installed (gt, bd, tmux, dolt, go)
- Confirm a town exists at ~/gt/ or $GT_TOWN_ROOT
- Register a rig for the current project (if not already registered)
- Verify the execute-phase.md gastown dispatch block is active
- Set `workflow.use_gastown: auto` in the project's GSD config

Do NOT run this if you want to disable gastown — use `workflow.use_gastown: false` instead.

## What It Does

### Step 1: Dependency Check
Check for required binaries. For each missing binary, print which package provides it
and how to install it (brew, go install, etc.). Do not auto-install — report only.

Required binaries and install hints:
- `gt` — Gas Town CLI: `go install github.com/gastownhall/gastown/cmd/gt@latest`
- `bd` (beads) — `go install github.com/gastownhall/gastown/cmd/bd@latest`
- `tmux` — `brew install tmux`
- `dolt` — `brew install dolt`
- `go` — https://go.dev/dl/

### Step 2: Town Detection
Check for a town at ~/gt/ or $GT_TOWN_ROOT.
Run `gt daemon status` from the town root. If not running, print:
  "Run: cd ~/gt && gt daemon start"
Do not start the daemon automatically.

### Step 3: Rig Check
From ~/gt, run: `gt rig list --json`
Look for a rig named after the current project directory basename.
If found: print "Rig {name} already registered."
If not found: run `gt rig create {basename} --town ~/gt` from the project root.
  If creation fails, print the error and the manual command.

### Step 4: Verify execute-phase.md Patch
Check that ~/.claude/get-shit-done/workflows/execute-phase.md contains:
  source "${HOME}/.claude/get-shit-done/bin/lib/gastown.sh"
If missing: print instructions to run `node $(gsd-town path)/../bin/postinstall.js` manually.

### Step 5: Enable Dispatch
Run: `node $HOME/.claude/get-shit-done/bin/gsd-tools.cjs config-set workflow.use_gastown auto`
Confirm: `node $HOME/.claude/get-shit-done/bin/gsd-tools.cjs config-get workflow.use_gastown`

### Step 6: Report
Print a summary table:
| Check | Status |
|-------|--------|
| gt binary | found / missing |
| bd binary | found / missing |
| tmux | found / missing |
| dolt | found / missing |
| go | found / missing |
| Town daemon | running / stopped / not found |
| Rig | registered / created / failed |
| execute-phase.md patch | present / missing |
| use_gastown config | auto / false / true |

If all checks pass: "gsd-town-setup complete. Run /gsd-execute-phase to dispatch polecats."
If any check failed: list the manual steps needed.

## Files Modified

- GSD project config (via gsd-tools config-set)
- May create a rig entry in ~/gt via gt rig create

## Success Criteria

- All 5 required binaries detected
- gt daemon running in town
- Rig registered for this project
- execute-phase.md contains gastown source line
- workflow.use_gastown = "auto" in project config

## Notes

- gastown.sh functions are sourced by execute-phase.md automatically when use_gastown != "false"
- The source line added by postinstall.js: `source "${HOME}/.claude/get-shit-done/bin/lib/gastown.sh"`
- This skill does NOT create the town — the user must create it manually with `gt init ~/gt` first
- One polecat per GSD plan (not per task) — plans have sequential task dependencies
- detect_gastown() returns "true" only when gt daemon is running and a town is accessible
