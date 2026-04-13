---
phase: 01-fork-and-critical-fixes
plan: 01
subsystem: infra
tags: [go, github, fork, beads, convoy, uuid, regression-test]

# Dependency graph
requires: []
provides:
  - "laulpogan/gastown fork on GitHub with upstream tracking configured"
  - "fix/3622-convoy-event-uuid branch with UUID regression test — TestPollEvents_UUIDStringNotInt64"
  - "Local clone: origin pushes to fork, upstream remote tracks gastownhall/gastown"
affects:
  - 01-02-PLAN
  - any plan requiring upstream PR submission to gastownhall/gastown

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fix branches created from upstream merge base (677877bf), not local HEAD, to avoid gsd-town docs in PR diffs"
    - "setupTestStore pattern (beads testcontainers) used for daemon integration tests"

key-files:
  created: []
  modified:
    - /Users/laul_pogan/Source/gastown/internal/daemon/convoy_manager_test.go
    - /Users/laul_pogan/Source/gastown/.git/config

key-decisions:
  - "Fix branches must be based on upstream merge base (677877bf), never local HEAD — prevents gsd-town planning docs from bleeding into upstream PRs"
  - "UUID fix PR value is the regression test, not a code change — beads v1.0.0 already scans event.ID as string; the test guards against future regressions"
  - "origin push URL → fork; upstream remote → gastownhall read-only; fork remote → laulpogan read-write"

patterns-established:
  - "Pattern: git cherry-pick to isolate fix onto clean base when commit chain gets polluted by hook-triggered branch switches"

requirements-completed:
  - FORK-01
  - FORK-03

# Metrics
duration: 25min
completed: 2026-04-13
---

# Phase 01 Plan 01: Fork and UUID Regression Test Summary

**GitHub fork laulpogan/gastown created, remotes configured, and TestPollEvents_UUIDStringNotInt64 committed to fix/3622-convoy-event-uuid — guards against int64 scan regression in beads convoy event poller**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-13T20:00:00Z
- **Completed:** 2026-04-13T20:25:00Z
- **Tasks:** 2
- **Files modified:** 1 (convoy_manager_test.go)

## Accomplishments

- Created laulpogan/gastown fork on GitHub via `gh repo fork gastownhall/gastown --clone=false`
- Configured local gastown clone: origin fetches from gastownhall, pushes to laulpogan fork; upstream remote reads from gastownhall
- Created fix/3622-convoy-event-uuid branch cleanly from upstream merge base 677877bf (no gsd-town docs in diff)
- Added TestPollEvents_UUIDStringNotInt64 — creates a real issue, closes it, calls GetAllEventsSince, asserts all event IDs have len==36 (UUID string format); PASS confirmed via testcontainers/Dolt
- Pushed clean branch to fork — PR-ready at https://github.com/laulpogan/gastown/pull/new/fix/3622-convoy-event-uuid

## Task Commits

Each task was committed atomically (commits in gastown repo, not gsd-town):

1. **Task 1: Create GitHub fork and configure remotes** — git config only (no source commit; pure remote config change)
2. **Task 2: Add UUID regression test on fix branch** — `902c5ea4` (test: daemon/convoy_manager_test.go)

**Plan metadata:** (this SUMMARY.md commit in gsd-town)

## Files Created/Modified

- `/Users/laul_pogan/Source/gastown/internal/daemon/convoy_manager_test.go` — Added TestPollEvents_UUIDStringNotInt64 (46 lines) at end of file; guards against CHAR(36) UUID scan-as-int64 regression (GH#3622)
- `/Users/laul_pogan/Source/gastown/.git/config` — Remote config: fork + upstream remotes added, origin push URL set to laulpogan fork

## Decisions Made

- Fork-branch creation must use `git checkout <merge-base> && git checkout -b` — not `git checkout -b` from local HEAD. Local HEAD has 38+ gsd-town planning commits that would pollute upstream PRs.
- The UUID bug (#3622) is already fixed in beads v1.0.0 source (event.ID is `string`). The PR value is the regression test that would have caught any future type change. No code fix needed.
- Remote topology: `origin fetch=gastownhall, push=laulpogan` (standard fork model); `upstream fetch=gastownhall` (for future syncs); `fork=laulpogan` (explicit named remote for pushing fix branches).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Commit chain pollution from hook-triggered branch switch**
- **Found during:** Task 2 (fix branch push verification)
- **Issue:** A post-commit hook (gastown's gt integration) switched the active branch after the UUID test commit, causing the commit to be orphaned from the local branch reference. The push to fork/fix/3622-convoy-event-uuid included an extra commit (82e07a05, the 3603 pre-flight test) that was parent of the UUID commit.
- **Fix:** Used `git cherry-pick a062cc0a` onto a fresh `fix/3622-clean` branch from 677877bf, renamed it to fix/3622-convoy-event-uuid, and force-pushed to fork. Final branch: 677877bf → 902c5ea4 (only the UUID test, no 3603 commit).
- **Files modified:** Only git branch refs (no source file changes)
- **Verification:** `git diff origin/main..fix/3622-convoy-event-uuid --name-only` shows only `internal/daemon/convoy_manager_test.go`
- **Committed in:** 902c5ea4 (cherry-pick preserves original test content)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix was essential for PR cleanliness. No scope creep. Test content unchanged.

## Issues Encountered

- gastown has a post-commit hook that switches branches after commits (likely gt state tracking). This caused the fix/3622 branch pointer to not advance after the test commit. Mitigated via cherry-pick onto clean base + force-push. Future fix branches in this repo should verify `git branch --show-current` immediately after commit.

## Known Stubs

None — no UI rendering or data wiring in this plan.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced. Git remote config and a test file only.

## User Setup Required

None - all automation completed. To open the PR when ready:
```
gh pr create --repo gastownhall/gastown --head laulpogan:fix/3622-convoy-event-uuid --base main --title "test(daemon): regression test for convoy event UUID string scan (GH#3622)" --body "Closes #3622"
```

## Next Phase Readiness

- Fork infrastructure complete — ready for Plan 01-02 (gt done pre-flight fix, FORK-02)
- fix/3603-gt-done-preflight branch already exists locally (pre-created by prior session); executor should verify it's clean relative to 677877bf before adding the pre-flight implementation

---
*Phase: 01-fork-and-critical-fixes*
*Completed: 2026-04-13*
