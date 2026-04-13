---
phase: 03-auto-setup
plan: 02
subsystem: cli
tags: [node, bash, gastown, lifecycle, teardown, preuninstall]

# Dependency graph
requires:
  - phase: 03-auto-setup
    plan: 01
    provides: lib/auto-setup.sh with detect_town, check_and_install_deps, bootstrap_town

provides:
  - bin/gsd-town.js setup subcommand wired to auto-setup.sh functions
  - bin/gsd-town.js teardown subcommand with --remove-data flag
  - bin/gsd-town.js status subcommand reporting daemon + managed town path
  - bin/postinstall.js --uninstall mode reversing all postinstall changes
  - package.json preuninstall script calling postinstall.js --uninstall

affects: [any user running gsd-town CLI, npm uninstall gsd-town lifecycle]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "runBash() helper sources gastown.sh + auto-setup.sh before each bash subprocess call"
    - "JSON.stringify for safe shell escaping of multi-line bash scripts (T-03-05)"
    - "rig_name sanitized to [a-z0-9-] via .replace(/[^a-z0-9-]/g, '-') in JS before bash"
    - "Dual-mode postinstall.js: --uninstall flag selects cleanup path, default is install"
    - "preuninstall hook in package.json for automatic npm uninstall cleanup"

key-files:
  created: []
  modified:
    - bin/gsd-town.js
    - bin/postinstall.js
    - package.json

key-decisions:
  - "runBash() sources both gastown.sh and auto-setup.sh — mirrors the caller-sources-both pattern from Plan 01"
  - "teardown preserves ~/.gsd-town by default; --remove-data required for deletion (T-03-07)"
  - "preuninstall does NOT stop the gt daemon — user must run teardown separately if desired"
  - "workflow.use_gastown: auto already works in detect_gastown() — no code change needed, documented in HELP"
  - "postinstall.js stays as single file for both install and uninstall (--uninstall flag branch at top)"

# Metrics
duration: ~2min
completed: 2026-04-13
---

# Phase 03 Plan 02: CLI Subcommands and Preuninstall Summary

**setup/teardown/status subcommands wired to lib/auto-setup.sh via runBash() helper; preuninstall cleanup reverses skill install and execute-phase.md patch on npm uninstall**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-13T21:04:13Z
- **Completed:** 2026-04-13T21:05:41Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `gsd-town setup` calls `check_and_install_deps` then `detect_town` (or `bootstrap_town` if no town found), all via `runBash()` which sources both gastown.sh and auto-setup.sh in each bash subprocess
- `gsd-town teardown` stops the gt daemon via `gt daemon stop`; `--remove-data` flag deletes `~/.gsd-town` (explicit only — T-03-07)
- `gsd-town status` reports both `detect_gastown()` result and managed town presence
- `bin/postinstall.js --uninstall` removes `~/.claude/skills/gsd-town-setup/` and filters gastown.sh lines from execute-phase.md; both skip cases log reason (T-03-08)
- `package.json` preuninstall script wired so `npm uninstall gsd-town` triggers cleanup automatically
- HELP string updated with all new commands and zero-config note documenting that `workflow.use_gastown: auto` works without additional setup

## Task Commits

1. **Task 1:** `e4e371f` feat(03-02): add setup, teardown, status subcommands to gsd-town CLI
2. **Task 2:** `4ca1481` feat(03-02): add preuninstall cleanup to postinstall.js, wire in package.json

## Files Created/Modified

- `/Users/laul_pogan/Source/gsd-town/bin/gsd-town.js` — Rewrote with runBash() helper, setup/teardown/status cases, updated HELP
- `/Users/laul_pogan/Source/gsd-town/bin/postinstall.js` — Added --uninstall branch (skill removal + execute-phase.md unpatch) before existing install logic
- `/Users/laul_pogan/Source/gsd-town/package.json` — Added preuninstall script entry

## Decisions Made

- **runBash() pattern:** Every auto-setup function call goes through a helper that sources both shell modules. Mirrors the "caller sources both" convention established in Plan 01 — no cross-sourcing inside the modules themselves.
- **teardown data preservation:** Default behavior keeps `~/.gsd-town` intact. Explicit `--remove-data` flag required for deletion. Prevents accidental data loss during routine daemon restarts.
- **preuninstall scope:** Only reverses what postinstall did (skill + execute-phase.md patch). Does not touch gt daemon or town data — those require explicit `gsd-town teardown`.
- **Single postinstall.js file:** `--uninstall` branch added at top of existing file rather than creating a separate preuninstall.js. Keeps related install/uninstall logic co-located and minimizes file count.
- **workflow.use_gastown: auto:** detect_gastown() in gastown.sh already treats anything other than "false" as enabled. No code change needed. Documented in HELP output.

## Deviations from Plan

None — plan executed exactly as written. All implementation details followed the plan's code snippets with no structural changes needed.

## Known Stubs

None — all subcommands are fully wired to real bash functions in lib/auto-setup.sh.

## Threat Flags

No new security-relevant surface introduced beyond what the plan's threat model already covers (T-03-05 through T-03-08 all addressed).

## Self-Check: PASSED

- [x] `bin/gsd-town.js` exists and `node --check` passes
- [x] `bin/postinstall.js` exists and `node --check` passes
- [x] `node bin/gsd-town.js help` shows setup, teardown, status, path, version, help
- [x] `node bin/postinstall.js --uninstall` exits 0 with "gsd-town preuninstall:" header
- [x] `grep "preuninstall" package.json` confirms script wired
- [x] `grep "runBash" bin/gsd-town.js` confirms shared helper used by setup and teardown
- [x] `grep "JSON.stringify" bin/gsd-town.js` confirms safe bash escaping
- [x] Commit `e4e371f` exists in git log
- [x] Commit `4ca1481` exists in git log
