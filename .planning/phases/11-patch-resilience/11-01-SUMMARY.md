---
phase: 11
plan: 01
subsystem: cli
tags: [doctor, patch-resilience, postinstall, cli]
requires: []
provides: [gsd-town-doctor]
affects: [bin/gsd-town.js, test/cli/cli.test.js]
tech-stack-added: []
tech-stack-patterns: [node-fs-existsSync, child_process-execFileSync]
key-files-created:
  - .planning/phases/11-patch-resilience/11-01-PLAN.md
key-files-modified:
  - bin/gsd-town.js
  - test/cli/cli.test.js
decisions:
  - Doctor checks implemented in-process with Node fs (no bash needed)
  - --fix delegates to postinstall.js subprocess to avoid requiring a side-effect module
  - Re-check after fix to confirm repair succeeded before exiting 0
metrics:
  duration: 8m
  completed: 2026-04-12
  tasks: 4
  files: 3
---

# Phase 11 Plan 01: Patch Resilience — Doctor Command Summary

**One-liner:** `gsd-town doctor` checks and auto-repairs the two GSD integration patches (execute-phase.md source line + skill directory) via in-process fs checks and postinstall.js subprocess on --fix.

## What Was Built

### doctor subcommand (DOCTOR-01, DOCTOR-02)

`gsd-town doctor` runs two checks:

1. **execute-phase.md patch** — reads `~/.claude/get-shit-done/workflows/execute-phase.md` and greps for `source` + `gastown.sh`. PASS if present, FAIL if file missing or line absent.
2. **gsd-town-setup skill** — checks `~/.claude/skills/gsd-town-setup/` exists on disk.

Exits 0 if all checks pass, 1 if any fail.

`gsd-town doctor --fix` spawns `node bin/postinstall.js` as a subprocess (avoiding require-time side effects), then re-runs the checks. Exits 0 only if the repair succeeds.

### status patch health (DOCTOR-03)

`gsd-town status` now appends a one-liner after the existing gastown/town output:

```
patches: OK
```
or
```
patches: MISSING — run gsd-town doctor --fix
```

### help text

`doctor` added to the Commands list in the HELP string.

### Tests (test/cli/cli.test.js)

5 new tests added, 10/10 passing:
- `doctor exits 0 or 1 (never crashes)`
- `doctor reports PASS or FAIL for each check`
- `doctor --fix exits 0`
- `doctor listed in help`

## Deviations from Plan

None — plan executed exactly as written. postinstall.js was not modified; subprocess invocation avoided any module side-effect issue cleanly.

## Self-Check: PASSED

- `bin/gsd-town.js` — modified, doctor case present
- `test/cli/cli.test.js` — modified, 5 doctor tests present
- `.planning/phases/11-patch-resilience/11-01-PLAN.md` — created
- Commit `c686b97` verified in git log
- All 10 CLI tests pass: `node --test test/cli/cli.test.js`
