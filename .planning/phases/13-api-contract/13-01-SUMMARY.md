---
phase: 13
plan: 01
name: api-contract
subsystem: docs
tags: [docs, changelog, api, versioning]
dependency_graph:
  requires: []
  provides: [DOCS-01, DOCS-02, DOCS-03]
  affects: [README.md, CHANGELOG.md]
tech_stack:
  added: []
  patterns: [Keep-a-Changelog, semver]
key_files:
  created:
    - CHANGELOG.md
    - .planning/phases/13-api-contract/13-01-PLAN.md
  modified:
    - README.md
decisions:
  - "Docs formatted as scan-friendly tables, not prose — matches CLAUDE.md Karpathy guideline (simplicity first)"
  - "gastown.sh: all 18 functions are public — no underscore-prefixed internal helpers in that file"
  - "Internal helpers annotated per-lib: _bs_* in bead-state.sh, _gsd_gt_cmd/_ensure_dep in auto-setup.sh, _gt_seance_cmd in seance.sh"
metrics:
  duration: 8m
  completed_date: "2026-04-14"
  tasks_completed: 2
  files_changed: 3
---

# Phase 13 Plan 01: API Contract & Docs Summary

**One-liner:** CHANGELOG.md in Keep-a-Changelog format plus Versioning and Public API tables in README covering all 28 functions across 4 lib files.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Create CHANGELOG.md | 98a16d3 |
| 2 | Add ## Versioning + ## Public API to README.md | 14ce569 |

## What Was Built

### CHANGELOG.md

- `[Unreleased]` section with compare link stub
- `[0.1.0] 2026-04-13` entry documenting v1/v2/v3 milestones under Added, plus a Fixed section for the four known bug fixes (3603, 3622, T-03-01, T-04-01)
- Footer links to GitHub releases/compare

### README.md — ## Versioning

Semver policy in a two-row table: pre-1.0 minor bumps may break API, patch bumps are safe; post-1.0 strict semver.

### README.md — ## Public API

Four lib subsections, each with Public and Internal tables:

| Lib | Public functions | Internal helpers |
|-----|-----------------|-----------------|
| `gastown.sh` | 18 | 0 (all public) |
| `auto-setup.sh` | 3 | 2 (`_gsd_gt_cmd`, `_ensure_dep`) |
| `bead-state.sh` | 4 | 3 (`_bs_bd_show`, `_bs_bd_list`, `_bs_load_registry`) |
| `seance.sh` | 3 | 1 (`_gt_seance_cmd`) |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- [x] `CHANGELOG.md` exists at repo root — `head -5` shows `# Changelog`
- [x] `README.md` contains `## Versioning` (line 155) and `## Public API` (line 168)
- [x] Commits 98a16d3 and 14ce569 confirmed in git log
- [x] All 4 lib files covered in Public API tables (28 functions total)
