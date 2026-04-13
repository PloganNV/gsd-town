---
phase: 05-polish
plan: 01
status: complete
started: 2026-04-13
completed: 2026-04-13
---

# Plan 05-01: README + Example Project

## What Was Built

### README.md (POLISH-01)
- Quickstart: 3-step install → setup → execute
- ASCII architecture diagram showing GSD → GSD-Town → Gas Town data flow
- Before/after comparison (single-agent vs multi-polecat)
- Data flow explanation (dispatch → sling → execute → result → collect → verify)
- Resilience features (stall detection, escalation, capacity, Seance)
- Configuration table (use_gastown, max_polecats, gsd_town_root)
- CLI reference (setup, status, teardown, path, version)
- GSD skill documentation (/gsd-town-setup)
- Requirements section (auto-installed deps)
- Gastown fork info (PRs #3603, #3622)

### Example Project (POLISH-02)
- examples/hello-polecats/ — minimal 2-plan phase
- Shows expected terminal output for polecat dispatch
- Includes PROJECT.md and ROADMAP.md for the example

## Commits

| Hash | Message |
|------|---------|
| 95cbc10 | docs(05): add README with quickstart, architecture, config reference + example project |

## Self-Check

- [x] README renderable on GitHub (no exotic markdown)
- [x] Architecture diagram is ASCII (works everywhere)
- [x] Quickstart is 3 steps or fewer
- [x] Config reference covers all settings
- [x] Example project has its own README explaining what happens
