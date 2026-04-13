# Phase 2: npm Package - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous)

<domain>
## Phase Boundary

Package the 13 gastown.sh dispatch functions as an installable npm package (`gsd-town`). Create a GSD skill (`/gsd-town-setup`) that configures any project for gastown dispatch. Make the execute-phase.md gastown dispatch block installable as a hook or patch with a single command.

</domain>

<decisions>
## Implementation Decisions

### Package Structure
- npm package name: `gsd-town`
- Contains: gastown.sh (bash functions), install script, GSD skill SKILL.md
- bin entry: `gsd-town` CLI for setup/status/teardown
- The bash functions are the core — Node.js is just the packaging/distribution layer
- Package copies gastown.sh to ~/.claude/get-shit-done/bin/lib/ on install (or symlinks)

### GSD Skill
- Skill name: gsd-town-setup
- Placed in: ~/.claude/skills/gsd-town-setup/SKILL.md (or project .claude/skills/)
- What it does: detects gastown, creates town if needed, registers rig, enables dispatch
- Triggered by: user running /gsd-town-setup in any project

### execute-phase.md Integration
- The gastown dispatch block (step 2.5 and step 4 polling) is already in execute-phase.md
- For portability: extract as a separate file that gets sourced/included
- Or: provide a patch command that adds the blocks to a vanilla execute-phase.md
- Decision: ship as a postinstall hook that patches execute-phase.md if GSD is detected

### Claude's Discretion
- package.json details (version, description, keywords)
- Whether to use symlinks or file copies for gastown.sh
- Error handling in the install/patch process

</decisions>

<code_context>
## Existing Code

- gastown.sh (13 functions): ~/.claude/get-shit-done/bin/lib/gastown.sh
- execute-phase.md (wired): ~/.claude/get-shit-done/workflows/execute-phase.md
- profile-output.cjs (gastown section): ~/.claude/get-shit-done/bin/lib/profile-output.cjs
- config.cjs (use_gastown key): ~/.claude/get-shit-done/bin/lib/config.cjs

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond making it installable and portable.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
