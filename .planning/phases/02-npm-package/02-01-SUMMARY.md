---
phase: 02-npm-package
plan: 01
subsystem: infra
tags: [npm, bash, cli, gastown, node]

# Dependency graph
requires: []
provides:
  - npm package scaffold (package.json with bin entry, files, postinstall)
  - lib/gastown.sh — all 13 gastown dispatch functions bundled for distribution
  - bin/gsd-town.js — CLI with status/path/version/help subcommands
  - bin/postinstall.js — stub postinstall hook (wired, prints sourcing instruction)
affects: [02-npm-package-02, execute-phase-integration]

# Tech tracking
tech-stack:
  added: [Node.js CLI (no deps), bash gastown.sh copy]
  patterns:
    - "bash-via-npm: bash library distributed as npm package, sourced at runtime"
    - "stub-postinstall: postinstall hook prints instructions, full impl deferred to PKG-03"
    - "dirname-anchored path: GASTOWN_SH resolved via __dirname, not user input"

key-files:
  created:
    - package.json
    - .gitignore
    - bin/gsd-town.js
    - bin/postinstall.js
    - lib/gastown.sh
  modified: []

key-decisions:
  - "No main field in package.json — this package has no importable Node.js API; bash functions are the API"
  - "lib/gastown.sh copied verbatim (cp + diff-verified) rather than symlinked — npm pack works correctly with real files"
  - "GASTOWN_SH path anchored to __dirname — no user-controlled input reaches execSync"

patterns-established:
  - "CLI entry: switch on process.argv[2], exit codes reflect semantic state (status exits 1 if gastown unavailable)"
  - "Stub postinstall: prints manual instructions, PKG-03 implements patch logic"

requirements-completed: [PKG-01]

# Metrics
duration: 8min
completed: 2026-04-13
---

# Phase 02 Plan 01: npm Package Scaffold Summary

**gsd-town npm package with 13-function gastown.sh, Node.js CLI (status/path/version/help), and stub postinstall — installable via `npm install -g .`**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-13T20:43:10Z
- **Completed:** 2026-04-13T20:51:45Z
- **Tasks:** 2
- **Files modified:** 5 created

## Accomplishments

- package.json scaffolded with bin entry, postinstall hook, and files field covering bin/, lib/, skills/
- lib/gastown.sh: byte-for-byte copy of all 13 gastown dispatch functions (diff-verified against source)
- bin/gsd-town.js: CLI with status (execSync + detect_gastown), path, version, help subcommands
- bin/postinstall.js: stub hook that prints sourcing instruction — deferred full impl to PKG-03

## Task Commits

1. **Task 1: Write package.json and .gitignore** - `aa6d4cf` (chore)
2. **Task 2: Copy gastown.sh, write gsd-town.js and postinstall.js** - `84616c6` (feat)

## Files Created/Modified

- `package.json` — npm package metadata: name=gsd-town, version=0.1.0, bin entry, postinstall, files
- `.gitignore` — excludes node_modules/, *.log, .DS_Store
- `lib/gastown.sh` — verbatim copy of 13-function gastown dispatch library
- `bin/gsd-town.js` — CLI entry point, __dirname-anchored GASTOWN_SH path
- `bin/postinstall.js` — stub postinstall, prints gastown.sh location and setup instruction

## Decisions Made

- No `main` field in package.json — the bash functions are the API, not a Node.js module
- Used `cp` + `diff` to copy gastown.sh rather than inline Write — guarantees byte-for-byte fidelity
- `gsd-town status` exits 1 when gastown unavailable — enables scripting (`if gsd-town status; then ...`)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `npm install -g .` from repo root will put `gsd-town` on PATH
- lib/gastown.sh is ready to be sourced: `source "$(gsd-town path)"`
- Plan 02-02 can now implement /gsd-town-setup skill and postinstall patch logic (PKG-02, PKG-03)

---
*Phase: 02-npm-package*
*Completed: 2026-04-13*

## Self-Check: PASSED

- `package.json` exists and is valid JSON with all required fields
- `lib/gastown.sh` exists and contains all 13 functions (verified via grep count = 13)
- `bin/gsd-town.js` exists, executable, responds to version/path/help
- `bin/postinstall.js` exists, exits 0
- Commits `aa6d4cf` and `84616c6` exist in git log
- `npm pack --dry-run` includes lib/gastown.sh, bin/gsd-town.js, bin/postinstall.js
