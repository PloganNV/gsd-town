# Changelog

All notable changes to GSD-Town are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [0.1.0] — 2026-04-13

### Prototype (internal, not published)

#### Added — v1.0: Proof-of-concept

- `lib/gastown.sh` with `detect_gastown()` and basic polecat dispatch (`gt sling`)
- `lib/auto-setup.sh` with `detect_town()`, `check_and_install_deps()`, `bootstrap_town()`
- `bin/gsd-town.js` CLI: `setup`, `status`, `teardown`, `path`, `version`
- `bin/postinstall.js` patches `execute-phase.md` with gastown dispatch block
- GSD skill: `skills/gsd-town-setup/` (`/gsd-town-setup` command)

#### Added — v2.0: Gastown drives

- Convoy-based phase tracking (`create_phase_convoy`, `add_bead_to_convoy`)
- Capacity governor (`check_capacity`, `queue_or_dispatch`)
- Seance predecessor context (`lib/seance.sh` — `get_seance_predecessors`, `build_seance_context`, `inject_seance_into_notes`)
- Bead-backed state management (`lib/bead-state.sh` — `generate_state_from_beads`, `read_plan_result_from_bead`, `check_phase_completion_from_convoy`, `sync_requirements_from_beads`)
- `store_bead_mapping` + `resolve_plan_from_bead` for gastown.json registry
- Stall detection and escalation check (`check_escalation_status`)
- `seance_context_block()` embedded in bead notes at dispatch time

#### Added — v3.0: Maintenance hardening

- `gsd-town doctor` — patch health check for execute-phase.md integration
- `gsd-town doctor --fix` — re-applies missing patches automatically
- `gsd-town status` — shows patch health alongside daemon/rig status
- Gastown submodule (`vendor/gastown`) for pinned dependency builds
- Fork patches ready for upstream PR:
  - `fix/3603-gt-done-preflight` — pre-flight push/PR enforcement
  - `fix/3622-convoy-event-uuid` — UUID regression fix

### Fixed

- Convoy event poller UUID type error (5-second error spam on `gt convoy watch`)
- `gt done` pre-flight: enforces commit/push/PR before marking beads complete
- Input sanitization on `bootstrap_town` rig names (`[a-z0-9-]` only — T-03-01)
- `check_capacity` treats non-numeric `scheduler.max_polecats` as unlimited (T-04-01)

---

[Unreleased]: https://github.com/laulpogan/gsd-town/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/laulpogan/gsd-town/releases/tag/v0.1.0
