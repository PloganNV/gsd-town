# Phase 3: Auto-Setup - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous)

<domain>
## Phase Boundary

GSD-Town spins up and manages its own town workspace. Auto-detect existing town, auto-install missing dependencies, auto-create town+rig+crew on first dispatch, and manage town lifecycle (start/stop daemon, cleanup on uninstall). The user never runs a `gt` command manually.

</domain>

<decisions>
## Implementation Decisions

### Managed Town Location
- GSD-Town's managed town lives at ~/.gsd-town/ (NOT ~/gt/ which is the user's personal town)
- This prevents conflicts with any existing gastown installation
- Town root stored in config: workflow.gsd_town_root (default ~/.gsd-town)

### Auto-Detection (AUTO-01)
- Check ~/.gsd-town/ first (managed town), then ~/gt/ (user town), then GT_TOWN_ROOT env
- If any exists and daemon is running: use it
- If exists but daemon stopped: start daemon automatically
- If none exists: proceed to auto-install

### Auto-Install (AUTO-02)
- Check each dependency: go, dolt, bd, tmux, gt
- For missing deps: brew install (macOS) or provide instructions (Linux)
- gt: build from gastown fork source (laulpogan/gastown) via make install
- This is the longest step — may take several minutes on first run

### Auto-Create (AUTO-03)
- On first dispatch: gt install ~/.gsd-town --git && gt up
- Register current project as rig: gt rig add <project-name> <project-path>
- Create crew: gt crew add <username>
- All happens inside the gsd-town CLI setup command

### Zero-Config (AUTO-04)
- workflow.use_gastown: "auto" means detect-and-dispatch automatically
- No config change needed — "auto" is the default when gsd-town is installed
- Override: workflow.use_gastown: false to disable

### Town Lifecycle (AUTO-05)
- Start daemon on first dispatch in a session
- Daemon keeps running (managed by gt daemon, auto-heartbeat)
- gsd-town teardown: stops daemon, optionally removes ~/.gsd-town/
- npm uninstall gsd-town: runs pre-uninstall that cleans up skill + patches

### Claude's Discretion
- Exact dependency detection logic (which commands to check)
- Whether to support Linux auto-install or just macOS for v1
- Timeout/retry logic for dependency installation

</decisions>

<code_context>
## Existing Code

- bin/gsd-town.js has setup/status/teardown subcommands (stubs from Phase 2)
- lib/gastown.sh has detect_gastown() for detection
- bin/postinstall.js handles skill copy + execute-phase.md patching
- The gastown fork is at laulpogan/gastown on GitHub

</code_context>

<specifics>
No specific requirements beyond the decisions above.
</specifics>

<deferred>
None.
</deferred>
