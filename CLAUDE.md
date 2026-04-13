<!-- GSD:project-start source:PROJECT.md -->
## Project

**GSD-Town**

GSD-Town is a portable GSD plugin that adds multi-agent execution to any project via Gas Town. Install it, point it at a gastown town, and `/gsd-execute-phase` automatically dispatches polecats (worker agents) instead of single-agent Task() calls. Each polecat gets its own tmux session and git worktree — true process-isolated parallel execution with crash recovery.

**Core Value:** Any GSD project gets multi-agent parallel execution with zero configuration — detect gastown, dispatch polecats, collect results.

### Constraints

- **Platform**: macOS primary, Linux secondary. No Windows yet.
- **Dependencies**: Go 1.25+, Dolt, beads (bd), tmux, Node.js 18+
- **GSD compatibility**: Must not break GSD for non-gastown users (capability detection)
- **Gastown fork**: Minimal divergence from upstream — only critical fixes, PR everything back
<!-- GSD:project-end -->

<!-- GSD:stack-start source:STACK.md -->
## Technology Stack

Technology stack not yet documented. Will populate after codebase mapping or first phase.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:gastown-start source:gastown.sh -->
## Gastown Integration

Gastown multi-agent orchestration is active on this machine.

**Town root:** ~/gt
**Rig:** gastown (default)
**Mayor:** Run `gt mayor attach` to enter the coordination session

## Orientation

- Source `$HOME/.claude/get-shit-done/bin/lib/gastown.sh` to access GSD dispatch helpers
- Dispatch functions: `detect_gastown()`, `create_plan_bead()`, `dispatch_plan_to_polecat()`
- Polecat results are written to bead notes before worktree teardown
- Registry: `.planning/gastown.json` maps plan IDs to bead IDs

## Hook Sync Safety

`gt hooks sync` writes ONLY `.claude/settings.json` — it does NOT touch CLAUDE.md files.
GSD context injected into CLAUDE.md is safe from hook sync overwrites.
<!-- GSD:gastown-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
