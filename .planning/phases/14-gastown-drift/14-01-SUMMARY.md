---
phase: 14
plan: 01
subsystem: drift-detection
tags: [ci, gastown, drift, submodule, testing]
dependency_graph:
  requires: [12-01]
  provides: [DRIFT-01, DRIFT-02, DRIFT-03]
  affects: [.github/workflows/test.yml, vendor/gastown]
tech_stack:
  added: []
  patterns: [bash-smoke-test, git-submodule-pinning, ci-advisory-job]
key_files:
  created:
    - test/drift/01-api-surface.sh
    - scripts/bump-gastown.sh
    - .planning/phases/14-gastown-drift/14-01-PLAN.md
  modified:
    - .github/workflows/test.yml
    - README.md
decisions:
  - "continue-on-error: true on drift job — advisory signal, not a merge gate"
  - "make build (not make install) in CI — skips daemon-restart and plugin-sync steps that need a live town"
  - "SKIP_UPDATE_CHECK=1 in CI — submodule is detached HEAD so check exits 0 anyway, but explicit is self-documenting"
  - "GT_BIN env var as override — lets CI set binary path without touching PATH"
  - "bd check is optional (skip if bd not found) — bd is not built in the gastown Makefile, only gt is"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-14T18:17:13Z"
  tasks_completed: 4
  tasks_total: 4
  files_changed: 5
---

# Phase 14 Plan 01: Gastown Drift Detection Summary

Bash-only API surface smoke test that catches upstream command/flag removal without requiring a running daemon. CI builds gt from the pinned submodule and verifies 12 specific checks on every push.

## What Was Built

### test/drift/01-api-surface.sh

No-daemon drift check. Resolves the gt binary via `GT_BIN` env var, `vendor/gastown/gt` build artifact, or PATH fallback. Runs `--help` on five commands and checks five flags:

Commands verified:
- `gt sling --help` exits 0
- `gt convoy stage --help` exits 0
- `gt polecat list --help` exits 0
- `gt done --help` exits 0
- `gt daemon status --help` exits 0

Flags verified (critical for gastown.sh dispatch logic):
- `gt sling`: `--no-convoy`, `--no-merge`
- `gt convoy stage`: `--launch`, `--json`
- `gt polecat list`: `--json`

bd check is optional — skips with a message if `~/go/bin/bd` and PATH `bd` are absent.

Verified against pinned submodule: **12/12 passed**.

### .github/workflows/test.yml — build-gastown-drift job

Parallel job (does not block the `test` job). Uses `actions/setup-go@v5` with `go-version-file: vendor/gastown/go.mod`. Builds with `SKIP_UPDATE_CHECK=1 make build` to avoid daemon-restart and plugin-sync steps. Sets `GT_BIN` env var pointing at the built binary, then runs `bash test/drift/01-api-surface.sh`. Marked `continue-on-error: true`.

### README.md — Gastown Compatibility section

Documents the known-good SHA, what CI checks, and two bump workflows: the `scripts/bump-gastown.sh` tool and the manual `git checkout` + drift test + commit steps.

### scripts/bump-gastown.sh

Bump helper that:
1. Records current `gt --help` as a baseline
2. Fetches and checks out the target ref in `vendor/gastown`
3. Builds the new gt binary
4. Runs the drift test — exits 1 with rollback instructions on failure
5. Diffs old vs new `gt --help` output so behavior changes are visible
6. Prints the `git add vendor/gastown && git commit` command but does not run it

## Verification

```
GT_BIN=/Users/laul_pogan/Source/gsd-town/vendor/gastown/gt \
  bash test/drift/01-api-surface.sh
# → results: 12 passed, 0 failed
```

## Deviations from Plan

None — plan executed exactly as written.

The only small clarification needed was that `bd` is not produced by `make build` in vendor/gastown (only `gt`, `gt-proxy-server`, `gt-proxy-client` are built). The test already handled this correctly by making the bd check optional.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

- test/drift/01-api-surface.sh: FOUND
- scripts/bump-gastown.sh: FOUND
- .planning/phases/14-gastown-drift/14-01-PLAN.md: FOUND
- .github/workflows/test.yml extended: FOUND (build-gastown-drift job)
- README.md Gastown Compatibility section: FOUND
- Commits: 6b999e8, c8a2392, 3172789, 5a23cb4 — all present
