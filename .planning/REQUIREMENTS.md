# Requirements: GSD-Town v3.0 — Long-Term Maintenance

**Defined:** 2026-04-14
**Core Value:** Survive change — GSD updates, gastown drift, contributor PRs

## v3.0 Requirements

### Patch Resilience

- [ ] **DOCTOR-01**: `gsd-town doctor` command checks if execute-phase.md patch is present
- [ ] **DOCTOR-02**: `gsd-town doctor --fix` re-applies missing patches automatically
- [ ] **DOCTOR-03**: `gsd-town status` shows patch health (integrated check)

### Continuous Integration

- [ ] **CI-01**: GitHub Actions workflow runs bash + CLI tests on every push and PR
- [ ] **CI-02**: Workflow checks out gastown submodule (so bd path detection works)
- [ ] **CI-03**: PRs get a test result comment before merge

### API Contract

- [ ] **DOCS-01**: CHANGELOG.md following Keep-a-Changelog format
- [ ] **DOCS-02**: Semver policy documented — pre-1.0 minor can break, post-1.0 follows semver
- [ ] **DOCS-03**: Public API list in README (functions safe to consume vs internal)

### Gastown Drift Detection

- [ ] **DRIFT-01**: Integration test against pinned `vendor/gastown` version runs in CI
- [ ] **DRIFT-02**: "Known good gastown version" documented in README
- [ ] **DRIFT-03**: Submodule bump workflow — test against new upstream before merging

## Future Requirements

- **AUTO-01**: Automated npm publish on git tag push
- **AUTO-02**: Conventional commits → automated changelog generation

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full CI matrix (multiple OS/node versions) | Premature — ship macOS support first |
| Codecov / coverage tracking | Bash coverage is messy; skip until it matters |
| Pre-commit hooks | Contributors can opt in; don't enforce |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCTOR-01 | Phase 1 | Pending |
| DOCTOR-02 | Phase 1 | Pending |
| DOCTOR-03 | Phase 1 | Pending |
| CI-01 | Phase 2 | Pending |
| CI-02 | Phase 2 | Pending |
| CI-03 | Phase 2 | Pending |
| DOCS-01 | Phase 3 | Pending |
| DOCS-02 | Phase 3 | Pending |
| DOCS-03 | Phase 3 | Pending |
| DRIFT-01 | Phase 4 | Pending |
| DRIFT-02 | Phase 4 | Pending |
| DRIFT-03 | Phase 4 | Pending |

**Coverage:** 12 requirements mapped, 0 unmapped

---
*Requirements defined: 2026-04-14*
