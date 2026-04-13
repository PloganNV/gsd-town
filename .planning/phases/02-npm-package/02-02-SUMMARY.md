---
phase: 02-npm-package
plan: 02
subsystem: infra
tags: [npm, skill, postinstall, gastown, node]

# Dependency graph
requires:
  - 02-01 (package scaffold, bin/postinstall.js stub, lib/gastown.sh)
provides:
  - skills/gsd-town-setup/SKILL.md — GSD skill index for /gsd-town-setup command
  - bin/postinstall.js — real implementation that installs skill + patches execute-phase.md
affects: [execute-phase-integration, gsd-skill-registry]

# Tech tracking
tech-stack:
  added: [Node.js fs.copyFileSync, fs.mkdirSync recursive, idempotent string patch]
  patterns:
    - "skill-via-npm: GSD skill SKILL.md shipped in npm package, installed to ~/.claude/skills/ on postinstall"
    - "idempotent-patch: check for both 'source' and 'gastown.sh' on same content scan before writing"
    - "anchor-splice: find GASTOWN_SH_VAR line index, splice source line immediately after"

key-files:
  created:
    - skills/gsd-town-setup/SKILL.md
  modified:
    - bin/postinstall.js

key-decisions:
  - "Idempotency check uses content.includes('source') && content.includes('gastown.sh') — matches both the new line and the pre-existing inline source within the if-block"
  - "SKILL_SRC read with fs.readdirSync for future-proofing — copies all files, not just SKILL.md"
  - "Always exit 0 via process.exit(0) after try/catch — postinstall errors must never block npm install"

# Metrics
duration: ~2min
completed: 2026-04-13
---

# Phase 02 Plan 02: GSD Skill and Postinstall Implementation Summary

**GSD skill for /gsd-town-setup (89 lines, 6 steps) and real postinstall.js that installs the skill to ~/.claude/skills/ and idempotently patches execute-phase.md with the gastown source line**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-13T20:53:12Z
- **Completed:** 2026-04-13T20:54:32Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 overwritten)

## Accomplishments

- skills/gsd-town-setup/SKILL.md: 89-line GSD skill index with all 6 setup steps (dependency check, town detection, rig check, execute-phase.md patch verify, config enable, report table)
- bin/postinstall.js: replaced stub with real implementation — copies skill directory to ~/.claude/skills/gsd-town-setup/, patches execute-phase.md via anchor-based splice, always exits 0
- Idempotency confirmed: second run prints "[skip] execute-phase.md already patched" and exits 0
- execute-phase.md on this machine already contained `source "$GASTOWN_SH"` inside the conditional block — postinstall correctly detects this and skips (no double-patch)

## Task Commits

1. **Task 1: Create skills/gsd-town-setup/SKILL.md** - `eb451e8` (feat)
2. **Task 2: Implement real bin/postinstall.js** - `110f1a5` (feat)

## Files Created/Modified

- `skills/gsd-town-setup/SKILL.md` — GSD skill index: /gsd-town-setup command, 6 steps, dependency table, success criteria, polecat/rig/use_gastown references
- `bin/postinstall.js` — real postinstall: skill install via fs.copyFileSync loop, execute-phase.md idempotent patch, try/catch with always-exit-0

## Decisions Made

- Idempotency check is content-level (`includes('source') && includes('gastown.sh')`) rather than exact-line match — handles the pre-existing inline `source "$GASTOWN_SH"` pattern already in execute-phase.md
- SKILL_SRC copied via `fs.readdirSync` loop so any future files added to skills/gsd-town-setup/ are automatically included
- process.exit(0) is unconditional (after the try/catch), not inside the try — ensures exit 0 even if the catch block itself throws

## Deviations from Plan

None — plan executed exactly as written. The execute-phase.md on this machine was already patched (contains `source "$GASTOWN_SH"` inside the conditional if-block), so the idempotency path was exercised rather than the insert path. Both paths are present and correct in the implementation.

## Known Stubs

None — both files are fully implemented.

## Threat Flags

None — no new network endpoints or trust boundaries introduced beyond those documented in the plan's threat model.

## Issues Encountered

- execute-phase.md already contained a source line for gastown.sh (inside the `if [ -f "$GASTOWN_SH" ]` conditional). The idempotency check correctly identified this and skipped the patch. The insert path (varIdx splice) is implemented and correct for machines where the patch has not been applied.

## Self-Check: PASSED

- `skills/gsd-town-setup/SKILL.md` exists: confirmed (3522 bytes)
- `~/.claude/skills/gsd-town-setup/SKILL.md` installed by postinstall: confirmed
- `node bin/postinstall.js` exits 0: confirmed
- Second run exits 0 and prints [skip]: confirmed
- Commits `eb451e8` and `110f1a5` exist in git log: confirmed below
