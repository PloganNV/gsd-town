# Phase 5: Polish - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous — infrastructure/docs phase)

<domain>
## Phase Boundary

README with quickstart, architecture diagram, and config reference. Example project demonstrating GSD-Town end-to-end. A user following the README should be able to dispatch their first polecat without reading source code.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — docs/polish phase.

Key constraints:
- README.md at repo root (not in .planning/)
- Architecture diagram as ASCII art or Mermaid (renderable on GitHub)
- Quickstart: npm install -g gsd-town → gsd-town setup → /gsd-execute-phase dispatches polecats
- Config reference: workflow.use_gastown, scheduler.max_polecats, gsd_town_root
- Example: minimal GSD project with 1 phase that dispatches a polecat

</decisions>

<code_context>
## Existing Code

The full package structure:
- package.json, bin/gsd-town.js, bin/postinstall.js
- lib/gastown.sh (18 functions), lib/auto-setup.sh (3 functions)
- skills/gsd-town-setup/SKILL.md

</code_context>

<specifics>
No specific requirements.
</specifics>

<deferred>
None.
</deferred>
