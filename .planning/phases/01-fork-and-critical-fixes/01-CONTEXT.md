# Phase 1: Fork + Critical Fixes - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase)

<domain>
## Phase Boundary

Fork gastown from gastownhall/gastown into the gsd-town repo structure. Apply two critical Go bug fixes: (1) `gt done` pre-flight checks to enforce commit/push/PR before marking beads complete (#3603), and (2) convoy event poller UUID type mismatch (#3622). Both fixes should be PR-ready for upstream.

</domain>

<decisions>
## Implementation Decisions

### Fork Strategy
- The gastown source is already cloned at /Users/laul_pogan/Source/gastown
- Fork it on GitHub under the user's account (laulpogan/gastown) for PR submission
- Keep the fork as a git submodule or subtree in gsd-town, OR keep it as a separate repo the user owns
- Decision: fork on GitHub, keep as separate repo at /Users/laul_pogan/Source/gastown, add as git remote

### gt done Pre-Flight Checks (#3603)
- Source file: internal/cmd/done.go
- Add pre-flight checklist before marking bead complete:
  1. Check working tree clean (git status --porcelain)
  2. Check branch pushed to remote (git rev-list @{u}..HEAD)
  3. Check PR exists (gh pr list --head <branch>)
- Auto-fix mode (default): commit, push, create PR automatically
- --strict mode: error instead of auto-fix
- --force mode: bypass all checks
- If auto-fix fails: mark bead as ESCALATED, not COMPLETED

### Convoy Event Poller UUID Fix (#3622)
- The events.id column is CHAR(36) UUID but Go code scans it as int64
- Source file: likely in internal/cmd/convoy.go or internal/convoy/
- Fix: change the scan target type from int64 to string
- Must handle both old and new convoy databases (backward compatible)

### Claude's Discretion
- Exact Go code structure for pre-flight checks
- Error message formatting
- Test strategy (unit tests for the fixes)

</decisions>

<code_context>
## Existing Code Insights

### Key Source Files
- /Users/laul_pogan/Source/gastown/internal/cmd/done.go — gt done implementation
- /Users/laul_pogan/Source/gastown/internal/cmd/convoy.go — convoy commands
- /Users/laul_pogan/Source/gastown/internal/cmd/convoy_watch.go — convoy event polling

### Build System
- Makefile with `make install` (codesigning + ICU4C CGo flags)
- go.mod requires Go 1.25.8
- Go 1.25.9 installed at /opt/homebrew/opt/go@1.25/bin/go

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the GitHub issue descriptions.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
