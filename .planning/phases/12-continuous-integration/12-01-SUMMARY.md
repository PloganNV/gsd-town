---
phase: 12
plan: 01
name: github-actions-ci
subsystem: ci
tags: [ci, github-actions, testing]
requirements: [CI-01, CI-02, CI-03]

dependency_graph:
  requires: []
  provides: [ci-pipeline]
  affects: [README.md]

tech_stack:
  added: [github-actions]
  patterns: [submodule-checkout, node-matrix-ci]

key_files:
  created:
    - .github/workflows/test.yml
    - .planning/phases/12-continuous-integration/12-01-PLAN.md
  modified:
    - README.md

decisions:
  - Use ubuntu-latest (bash and python3 available by default — no extra setup needed)
  - npm install --ignore-scripts to skip postinstall (postinstall patches execute-phase.md, irrelevant in CI)
  - GSD_TOWN_INTEGRATION intentionally absent — integration tests require live daemon
  - submodules: recursive ensures vendor/gastown is checked out for bash function tests

metrics:
  duration_seconds: 36
  completed_date: "2026-04-14"
  tasks_completed: 2
  files_changed: 3
---

# Phase 12 Plan 01: GitHub Actions CI Summary

GitHub Actions workflow that runs bash syntax, function definition, and CLI tests on every push to main and every PR using ubuntu-latest + Node 20 with recursive submodule checkout; CI badge added to README.

## What Was Built

- `.github/workflows/test.yml` — full CI pipeline triggered on `push` (main) and `pull_request`. Checks out repo with `submodules: recursive` (vendor/gastown required by bash tests), installs Node 20, runs `npm test` which calls `bash test/run.sh`.
- CI badge in `README.md` pointing to the workflow on the main branch.

## Key Decisions

1. **ubuntu-latest** — bash and python3 ship by default; no extra apt installs needed for the current test suite.
2. **`--ignore-scripts` on npm install** — the `postinstall` script patches `~/.claude/get-shit-done/workflows/execute-phase.md`, which doesn't exist in CI and would fail. Skipping it is correct; tests don't depend on the patched file.
3. **No `GSD_TOWN_INTEGRATION` env var** — `test/run.sh` already defaults to skipping integration tests when the var is absent. The comment in the workflow makes the intent explicit.
4. **Recursive submodule checkout** — `vendor/gastown` is referenced by `02-functions-defined.sh` which sources `lib/gastown.sh`. Without the submodule the bash tests would fail to find function definitions.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `.github/workflows/test.yml` exists
- [x] `README.md` contains CI badge
- [x] `.planning/phases/12-continuous-integration/12-01-PLAN.md` exists
- [x] Commit a8cf263 exists

## Self-Check: PASSED
