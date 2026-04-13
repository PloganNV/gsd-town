---
phase: 03-auto-setup
plan: 01
subsystem: infra
tags: [bash, gastown, gt, dolt, beads, brew, auto-install]

# Dependency graph
requires:
  - phase: 02-npm-package
    provides: lib/gastown.sh, bin/gsd-town.js CLI skeleton

provides:
  - lib/auto-setup.sh with detect_town(), check_and_install_deps(), bootstrap_town()
  - Managed town detection at ~/.gsd-town, ~/gt, $GT_TOWN_ROOT
  - macOS brew auto-install for go/dolt/tmux; go install for bd; source build for gt
  - Idempotent town+rig+crew bootstrap with ~/.gsd-town-config registry

affects: [03-auto-setup plan 02, bin/gsd-town.js setup subcommand, any caller sourcing auto-setup.sh]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Module-level var declarations at top of sourced bash files"
    - "Internal _gsd_gt_cmd() helper avoids re-defining gt_cmd() from gastown.sh"
    - "_ensure_dep() helper pattern for idempotent dependency installs"
    - "_local_gt() inline function for PATH-extended gt invocations inside bootstrap"
    - "Caller sources both gastown.sh and auto-setup.sh — files don't cross-source each other"

key-files:
  created:
    - lib/auto-setup.sh
  modified: []

key-decisions:
  - "auto-setup.sh does NOT source gastown.sh internally — caller is responsible for sourcing both"
  - "Internal _gsd_gt_cmd() defined as local analog of gt_cmd() to avoid dependency on gastown.sh being sourced"
  - "[T-03-01] rig_name slugified to [a-z0-9-] via tr+sed before passing to gt commands"
  - "username from git config also slugified for crew add — same threat surface"
  - "detect_town() continues to next candidate on daemon start failure rather than aborting"
  - "bd check uses OR condition: command -v bd || ~/.local/bin/bd — handles go install path"

patterns-established:
  - "Bash modules in lib/ follow same set -euo pipefail + header comment block pattern as gastown.sh"
  - "Each bash function has comment block documenting args, outputs, returns before the function body"
  - "GT commands always run with PATH extended to include ~/go/bin and /opt/homebrew/bin"

requirements-completed: [AUTO-01, AUTO-02, AUTO-03]

# Metrics
duration: 2min
completed: 2026-04-13
---

# Phase 03 Plan 01: Auto-Setup Module Summary

**Bash auto-setup module with detect_town() priority-ordered detection, brew/source-build dep install, and idempotent bootstrap_town() creating managed ~/.gsd-town with rig+crew+config**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-13T21:01:03Z
- **Completed:** 2026-04-13T21:02:35Z
- **Tasks:** 3 (all combined into one file in a single pass)
- **Files modified:** 1

## Accomplishments

- `detect_town()` checks `~/.gsd-town`, `~/gt`, `$GT_TOWN_ROOT` in priority order; starts stopped daemon automatically before returning the path
- `check_and_install_deps()` handles all five gastown dependencies (go, dolt, tmux, bd, gt) with macOS brew for brew-installable deps, `go install` for bd, and source clone + `make install` for gt; returns 1 on Linux with printed instructions
- `bootstrap_town()` idempotently provisions managed town via `gt install`, starts daemon, registers project rig, adds crew member from git config, and writes `~/.gsd-town-config`; rig_name and username sanitized to `[a-z0-9-]` (threat T-03-01)

## Task Commits

All three tasks were implemented together and committed atomically:

1. **Task 1: detect_town()** — included in `708f0dd`
2. **Task 2: check_and_install_deps()** — included in `708f0dd`
3. **Task 3: bootstrap_town()** — included in `708f0dd`

- `708f0dd` feat(03-01): add lib/auto-setup.sh with town detection, dep install, bootstrap

## Files Created/Modified

- `/Users/laul_pogan/Source/gsd-town/lib/auto-setup.sh` — Full auto-setup module: detect_town(), check_and_install_deps(), bootstrap_town(), _gsd_gt_cmd() helper, _ensure_dep() helper

## Decisions Made

- **No cross-sourcing:** auto-setup.sh does not source gastown.sh. Both files are designed to be sourced by the caller. This avoids side effects from double-sourcing and keeps each module independent.
- **Internal `_gsd_gt_cmd()`:** Rather than depending on `gt_cmd()` from gastown.sh, auto-setup.sh defines its own private `_gsd_gt_cmd()` with identical logic. This lets auto-setup.sh work standalone.
- **Rig name sanitization (T-03-01):** `tr + sed` pipeline strips input to `[a-z0-9-]` before passing to gt. Same treatment applied to crew username derived from `git config user.name`.
- **Daemon start failure is non-fatal in detect_town():** If a candidate town exists but daemon start fails, the function continues to the next candidate rather than returning an error. This avoids false negatives when one of three candidates is broken.
- **bd binary path:** `check_and_install_deps()` checks both `command -v bd` and `~/${HOME}/go/bin/bd` since `go install` puts binaries in `~/go/bin` which may not be in PATH.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Sanitized crew username (T-03-01 threat extension)**
- **Found during:** Task 3 (bootstrap_town implementation)
- **Issue:** Plan specified slugifying rig_name but the crew username derived from `git config user.name` also flows into a `gt crew add` command — same injection surface.
- **Fix:** Applied same `tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//'` pipeline to username.
- **Files modified:** lib/auto-setup.sh (bootstrap_town function)
- **Verification:** Sanitization pipeline tested inline; bash -n passes.
- **Committed in:** 708f0dd

---

**Total deviations:** 1 auto-fixed (Rule 2 - missing critical security mitigation)
**Impact on plan:** Minimal scope — one additional `tr+sed` pipeline on username. No structural change.

## Issues Encountered

None — plan executed cleanly on first attempt.

## Next Phase Readiness

- `lib/auto-setup.sh` is ready to be sourced by `bin/gsd-town.js` subprocess calls
- Plan 02 (setup/teardown subcommands) can now wire `detect_town`, `check_and_install_deps`, and `bootstrap_town` directly
- No blockers

---
*Phase: 03-auto-setup*
*Completed: 2026-04-13*

## Self-Check: PASSED

- [x] `lib/auto-setup.sh` exists at correct path
- [x] `bash -n lib/auto-setup.sh` exits 0 (syntax valid)
- [x] All three functions sourced and typed correctly
- [x] Commit `708f0dd` exists in git log
- [x] No gastown.sh sourcing internally
- [x] GSD_TOWN_ROOT defaults to ~/.gsd-town
- [x] GT_FORK_REPO points to laulpogan/gastown
- [x] Threat T-03-01 mitigated (rig_name + username slugified)
