# Phases 7-10: Gastown Internals - Research

**Researched:** 2026-04-12
**Domain:** gastown Go source — witness, refinery, beads, seance
**Confidence:** HIGH (all findings read directly from gastown source in `/Users/laul_pogan/Source/gastown`)

---

## Summary

This document covers four GSD-Town integration phases: Witness monitoring (7), Refinery merge
queue (8), Beads as truth source (9), and Seance continuity (10). All findings were obtained by
reading the actual Go source at `/Users/laul_pogan/Source/gastown`. No web lookups required —
the source is authoritative.

The core architectural insight for all four phases: **gastown is ZFC (Zero File Config)**. Running
state lives in tmux sessions, not state files. Beads (Dolt-backed issue tracking) is the
persistent truth store. GSD integrates by reading bead JSON output and by subscribing to the
`.events.jsonl` feed — there is no internal Go API to call.

**Primary recommendation:** GSD is an external observer. It polls `bd list/show --json` and reads
`~/gt/.events.jsonl`. It does not embed into gastown internals or modify Go source. All four
phases can be implemented in bash scripts and Node.js without any gastown forks.

---

## Phase 7 — Witness Integration

### How Witness Monitors Polecats

[VERIFIED: gastown/internal/witness/manager.go + handlers.go]

The Witness is a Claude Code agent running in a dedicated tmux session (`gt-<prefix>-witness`).
It is NOT a Go daemon that polls. It is an LLM agent that patrols by reading its mail inbox.

Key facts:
- One Witness per rig (`gt witness start <rig>`)
- Launched by `manager.Manager.Start()` — spawns Claude in a tmux session via
  `tmux new-session`, passes startup prompt "Run `gt prime --hook` and begin patrol"
- The Claude agent itself decides when/how to check polecat health; the Go code just
  provides protocol parsing helpers
- Session health check: `t.CheckSessionHealth(sessionName, maxInactivity)` returns a
  `tmux.ZombieStatus` — `SessionHealthy`, or zombie variants

### Does Witness Emit Events?

[VERIFIED: gastown/internal/events/events.go]

Yes. Events are appended as JSON to `~/gt/.events.jsonl` (the `EventsFile` constant). Relevant
witness event types:

```go
TypePatrolStarted   = "patrol_started"
TypePolecatChecked  = "polecat_checked"
TypePolecatNudged   = "polecat_nudged"
TypeEscalationSent   = "escalation_sent"
TypeEscalationAcked  = "escalation_acked"
TypeEscalationClosed = "escalation_closed"
TypePatrolComplete   = "patrol_complete"
```

Each event is a JSON line:
```json
{"ts":"2026-04-12T10:00:00Z","source":"gt","type":"patrol_complete","actor":"gastown/witness","payload":{"rig":"gastown","polecat_count":3,"message":"..."}}
```

There is NO subscription mechanism (no channels, no websockets). The only interface is
tail-reading `.events.jsonl`.

### Is There a Subscription Mechanism?

[VERIFIED: gastown/internal/channelevents/channelevents.go]

There are two event systems:

1. **`.events.jsonl`** — Audit log in town root. GSD tails this file. No push mechanism; poll
   or `tail -F`.

2. **`~/gt/events/<channel>/*.event`** — File-based channel events used internally for
   instant unblocking (e.g., Witness emits `MERGE_READY` to the `refinery` channel so the
   Refinery's await-event loop unblocks). GSD has no need to emit into these channels.
   External observers (like GSD) should read `.events.jsonl` instead.

### How Witness Detects Stalls — Polecat States

[VERIFIED: gastown/internal/beads/status.go + witness/protocol.go]

Polecat states stored on agent beads (`agent_state` field in bead description):
```
spawning, working, done, stuck, escalated, idle, running, nuked, awaiting-gate
```

Witness detects stalls via:
- `tmux.CheckSessionHealth(sessionName, maxInactivity)` — returns `ZombieStatus` for hung or
  dead sessions
- `HungSessionThresholdMinutes` — minutes of tmux inactivity before session is "hung"
- Reading agent bead `agent_state` field to check for `stuck`, `escalated`, `done` (crash
  recovery)

Witness protocol messages it handles (from `witness/protocol.go`):
- `POLECAT_DONE <name>` — polecat signals completion
- `LIFECYCLE:Shutdown <name>` — daemon-triggered shutdown
- `HELP: <topic>` — polecat requesting intervention (routed by category/severity)
- `MERGED <name>` — refinery confirms merge
- `MERGE_FAILED <name>` — refinery reports failure
- `DISPATCH_ATTEMPT/OK/FAIL <name>` — dispatch tracking
- `IDLE_PASSIVATED <name>` — polecat timed out and passivated

Help categories (HELP message routing):
```go
HelpCategoryDecision  // → deacon
HelpCategoryHelp      // → deacon
HelpCategoryBlocked   // → mayor
HelpCategoryFailed    // → deacon
HelpCategoryEmergency // → overseer
HelpCategoryLifecycle // → witness
```

### Can GSD Subscribe to Witness Events Without Being a Gastown Agent?

[VERIFIED: source read]

Yes. GSD subscribes by tailing `~/gt/.events.jsonl` and filtering for event types relevant to
polecat health (`patrol_complete`, `polecat_checked`, `polecat_nudged`, `escalation_sent`).
No credentials, no API, no special role required — it is a plain JSONL append-only log.

Command pattern for GSD skill:
```bash
# Read last N witness events for a rig
tail -n 200 ~/gt/.events.jsonl | jq -c 'select(.type | startswith("patrol") or startswith("polecat"))'
```

### `gt witness` CLI Commands

[VERIFIED: gastown/internal/cmd/witness.go]

```
gt witness start <rig>     # Start witness (spawns Claude in tmux)
gt witness stop <rig>      # Kill tmux session
gt witness restart <rig>   # Stop + start
gt witness status <rig>    # Show running state (--json flag available)
gt witness attach <rig>    # Attach to tmux session
```

`gt witness status --json` output shape:
```go
type WitnessStatusOutput struct {
    Running           bool     `json:"running"`
    RigName           string   `json:"rig_name"`
    Session           string   `json:"session,omitempty"`
    MonitoredPolecats []string `json:"monitored_polecats,omitempty"`
}
```

GSD can call `gt witness status <rig> --json` to get running state.

---

## Phase 8 — Refinery Merging

### How Refinery Works

[VERIFIED: gastown/internal/refinery/manager.go + types.go + cmd/refinery.go]

The Refinery is another Claude Code agent in a tmux session, one per rig. It processes merge
requests sequentially:

1. Polecat calls `gt done` — creates an MR bead (with label `gt:merge-request`) and emits
   `MERGE_READY` channel event
2. Witness receives `POLECAT_DONE`, calls `notifyRefineryMergeReady()` which:
   - Emits `MERGE_READY` to channel `~/gt/events/refinery/`
   - Nudges the Refinery tmux session directly
3. Refinery agent polls `gt refinery queue` to find open MR beads, processes them

Merge queue is backed by beads: open issues with label `gt:merge-request` in the wisps table.

### MR (Merge Request) Bead Lifecycle

[VERIFIED: gastown/internal/refinery/types.go]

Two parallel state machines:

**MRStatus** (stored in bead's `status` field):
```
open → in_progress → closed
```

**MRPhase** (stored in bead's description/checkpoint fields, more granular):
```
ready → claimed → preparing → prepared → merging → merged
                              ↘ rejected
                 ↘ failed → ready (retry)
```

Valid transitions:
- `ready → claimed` (Refinery claims MR)
- `claimed → preparing` (rebase + quality gates start)
- `preparing → prepared` (gates complete)
- `prepared → merging` (ff-merge + push)
- `prepared → rejected` (agent diagnosis: fatal failure)
- `prepared → ready` (failure is transient, retry)
- `merging → merged` (success)
- `merging → failed` (transient)
- `failed → ready` (retry eligible)

### How a Polecat Submits to the Refinery Queue

[VERIFIED: gastown/internal/cmd/done.go + witness/handlers.go]

`gt done` flow (summarized):
1. Auto-detects branch and issue ID from current git branch
2. Creates MR bead in wisps table (`bd create --label gt:merge-request ...`)
3. Sets `exit_type`, `mr_id`, `branch` fields in agent bead description
4. Sets agent bead `agent_state = idle`
5. Notifies Witness via mail (`POLECAT_DONE <name>` message)
6. Witness then calls `notifyRefineryMergeReady()` → channel event + nudge

So the polecat does NOT directly contact the Refinery. The chain is:
```
gt done → MR bead created + Witness notified → Witness nudges Refinery
```

Flags relevant to GSD pre-flight work:
- `--status ESCALATED|DEFERRED` — skips MR creation
- `--pre-verified` — signals gates already passed
- `--target <branch>` — explicit MR target (overrides auto-detect)
- `--issue <id>` — explicit issue ID

### How GSD Knows When a Merge is Complete

[VERIFIED: gastown/internal/events/events.go + refinery/manager.go]

Read `.events.jsonl` for:
```go
TypeMergeStarted = "merge_started"  // Refinery picked up the MR
TypeMerged       = "merged"         // Successful merge
TypeMergeFailed  = "merge_failed"   // Failure (with reason)
TypeMergeSkipped = "merge_skipped"  // Skipped (e.g., conflict)
```

MergePayload shape:
```json
{"mr": "<mr-bead-id>", "worker": "<polecat-name>", "branch": "<branch>", "reason": "<if failed>"}
```

Alternatively, poll `gt refinery queue [rig] --json` or `bd show <mr-bead-id> --json` and watch
for `status: "closed"` with close reason `"merged"`.

### Does `gt done` Already Submit to the Refinery? (Pre-flight Interaction)

[VERIFIED: gastown/internal/cmd/done.go]

Yes. `gt done` without flags does the full flow: commits, pushes, creates MR bead, notifies
Witness. GSD's pre-flight concern (preventing double-submission, validating state before `gt done`
is called) should happen BEFORE calling `gt done`, not by replacing it.

GSD should call `gt done` as-is. The pre-flight phase (Phase 6 fix) wraps the call — it checks
preconditions, then calls `gt done` when ready.

**Warning:** `gt done` guards against non-polecat callers:
```go
if actor != "" && !isPolecatActor(actor) {
    return fmt.Errorf("gt done is for polecats only (you are %s)...")
}
```
The `BD_ACTOR` env var must be set to a polecat identity when calling from a GSD skill that
wraps `gt done`.

---

## Phase 9 — Beads as Truth

### How `bd` Stores Data

[VERIFIED: gastown/internal/beads/beads.go + fields.go + beads_agent.go]

Beads is a Dolt-backed issue tracker. Data lives in two tables:
- **`issues`** — git-synced, persistent work items
- **`wisps`** (ephemeral=true) — not synced to git, used for MR beads, cleanup wisps, swarm wisps

Every bead has:
```go
type Issue struct {
    ID          string          // e.g., "gt-abc12"
    Title       string
    Description string          // Free-text; structured fields parsed as "key: value" lines
    Status      string          // open, closed, in_progress, tombstone, blocked, pinned, hooked
    Priority    int             // 0-4
    Type        string          // Deprecated; use Labels
    CreatedAt   string          // RFC3339
    CreatedBy   string
    UpdatedAt   string
    ClosedAt    string
    Parent      string          // Parent issue ID
    Assignee    string          // e.g., "gastown/Toast"
    Children    []string
    DependsOn   []string
    Blocks      []string
    BlockedBy   []string
    Labels      []string        // e.g., ["gt:agent", "gt:merge-request"]
    Ephemeral   bool
    AcceptanceCriteria string
    HookBead    string          // Agent-only: currently pinned work bead
    AgentState  string          // Agent-only: spawning/working/done/stuck/escalated/idle/running/nuked
    Metadata    json.RawMessage // Extension point (delegation, merge-slot state)
}
```

### Can GSD Store Arbitrary Structured Data in Beads?

[VERIFIED: gastown/internal/beads/fields.go + beads_agent.go]

Yes. Beads supports two structured field mechanisms:

**1. Description key-value lines** (primary mechanism):
```
title line

key1: value1
key2: value2
```
Gastown uses this for `AgentFields` (agent beads), `AttachmentFields` (work beads), `MRFields`
(MR beads), and `ConvoyFields` (convoy beads). GSD can store STATE.md fields here using the
same `key: value` line format. Fields not recognized by gastown parsers are ignored safely.

**2. Metadata JSON blob** (`metadata` field) — for complex nested data. Used by gastown for
delegation state and merge-slot queues.

**Recommended approach for GSD:** Store phase-level state in the bead description as key-value
lines. Example:
```
GSD Phase 7: Witness Integration

gsd_phase: 7
gsd_status: in_progress
gsd_started_at: 2026-04-12T10:00:00Z
gsd_wave: 2
```

### Query Interface: `bd list --json` and `bd show --json`

[VERIFIED: gastown/internal/beads/beads.go + witness/handlers.go (BdCli)]

**CRITICAL NOTE:** `bd v0.59+` requires `--flat` flag for `bd list --json` to produce JSON. The
gastown codebase injects this automatically via `InjectFlatForListJSON(args)`. GSD scripts must
do the same:
```bash
bd list --json --flat             # NOT: bd list --json
bd list --json --flat --allow-stale   # bd v0.60+ supports --allow-stale
```

`bd show <id> --json` returns an array (per `mail/mailbox.go:499` comment). Parse accordingly:
```bash
bd show gt-abc12 --json | jq '.[0]'   # First element is the issue
```

`bd list --json --flat` returns newline-delimited JSON objects (one per line), OR a plain text
"No issues found." — GSD scripts must handle both.

Key list filters:
```bash
bd list --json --flat --label gt:agent --status open
bd list --json --flat --label gt:merge-request --status all
bd list --json --flat --type convoy              # convoy beads
bd list --json --flat --assignee gastown/Toast   # by polecat
```

### Aggregating Bead Status into a Phase-Level View

[VERIFIED: gastown/internal/beads/beads.go + convoy/operations.go]

Gastown uses **convoy beads** (label `gt:convoy`, or type `convoy`) to aggregate related work
beads. A convoy bead tracks child issues and reports aggregate status. GSD phases map naturally
to convoys.

GSD can:
1. Create a convoy bead for each phase with `bd create --label gt:convoy --title "Phase 7: ..."`.
2. Add child beads (polecat work items) with `bd dep add <parent> <child>`.
3. Query convoy status: `bd show <convoy-id> --json` returns `children[]`, `dependency_count`,
   `blocked_by_count`.

Alternatively, GSD queries all beads with a phase label:
```bash
bd list --json --flat --label gsd:phase-7
```

Convoy status derives from child bead status — no separate aggregate field. GSD must aggregate
itself (count open/closed children).

### Convoy → Bead Relationship

[VERIFIED: gastown/internal/convoy/operations.go]

Convoys are regular beads with type `convoy`. They track issues via the beads dependency graph
(`children`/`depends_on`). Convoy status is not auto-computed — the convoy manager watches child
events and updates the convoy bead's status field (e.g., `staged_ready`, `staged_warnings`, or
`closed` when all children close).

GSD should NOT rely on convoy status auto-propagation — it needs to count children explicitly.

---

## Phase 10 — Seance Continuity

### How Seance Works

[VERIFIED: gastown/internal/cmd/seance.go]

`gt seance` is a CLI command that enables talking to predecessor Claude Code sessions.

Two modes:
1. **Discovery mode** (`gt seance [--role X] [--rig Y]`) — reads `~/gt/.events.jsonl`, filters
   for `session_start` events, displays a table of discoverable sessions
2. **Talk mode** (`gt seance --talk <session-id> [-p "question"]`) — spawns `claude
   --fork-session --resume <id>`, loading the predecessor's full context read-only

The `--fork-session` flag is Claude-specific. Only agents with `SupportsForkSession: true` in
their preset config can do seance. Gemini, OpenCode, Cursor: not supported (as of source read).

### What Context Does Seance Provide to a Resumed Polecat?

[VERIFIED: source]

Seance does NOT resume the polecat's session as a running agent. It spawns a new Claude instance
with `--fork-session --resume <session-id>` which loads the predecessor's conversation log
(`.jsonl` file from `~/.claude/projects/<project-dir>/<session-id>.jsonl`) as read-only context.

The resumed session has full access to the predecessor's:
- All tool calls and results
- All messages exchanged during the session
- The session's final state at the time it ended

It cannot modify the predecessor's state — it's a snapshot read.

### How a Polecat Queries Its Predecessors

[VERIFIED: gastown/internal/session/startup.go + cmd/seance.go]

Sessions are discoverable because `gt prime --hook` (called by the `SessionStart` hook)
emits a `session_start` event to `.events.jsonl` with this payload:

```go
func SessionPayload(sessionID, role, topic, cwd string) map[string]interface{} {
    return map[string]interface{}{
        "session_id": sessionID,
        "role":       role,
        "actor_pid":  fmt.Sprintf("%s-%d", role, os.Getpid()),
        "topic":      topic,   // e.g., "assigned:gt-abc12"
        "cwd":        cwd,
    }
}
```

The startup beacon format embedded in the Claude session title:
```
[GAS TOWN] <recipient> <- <sender> • <timestamp> • <topic[:mol-id]>
```

This makes the session findable in Claude's `/resume` picker by session title substring match.

A polecat finds predecessors by:
1. `gt seance --role polecat --rig <rig>` to list recent polecat sessions for that rig
2. `gt seance --talk <session-id>` to load a specific predecessor's context
3. Alternatively, scan `.events.jsonl` for `session_start` events matching topic `assigned:<bead-id>`

### Is Seance Automatic or Opt-In?

[VERIFIED: gastown/internal/cmd/seance.go + session/startup.go]

**Seance capability is opt-in at two levels:**

1. **Session discovery requires `gt prime --hook`** to be wired as a `SessionStart` hook. Without
   it, `session_start` events are not emitted and sessions are undiscoverable.
   (See config/hooks_test.go: "The --hook flag is required for seance to discover predecessor sessions.")

2. **Talking to a predecessor requires the human or agent to explicitly call `gt seance --talk`.**
   No agent automatically resumes predecessors — they must initiate it.

GSD integration: GSD can suggest seance calls to polecats by including the predecessor session ID
in the polecat's startup context (via `polecat-CLAUDE.md` injection). The polecat then decides
whether to run `gt seance --talk <id>`.

### What Is Stored in `.events.jsonl`? What Can Be Queried?

[VERIFIED: gastown/internal/events/events.go]

Location: `<town_root>/.events.jsonl` (NOT `~/gt/.events.jsonl` — it's relative to the town root
directory, which is typically `~/gt/` but may differ. Use `workspace.Find()` logic: walk up from
cwd looking for `mayor/` directory).

File format: Newline-delimited JSON (one event per line).

Event structure:
```json
{
  "ts": "2026-04-12T10:00:00Z",
  "source": "gt",
  "type": "session_start",
  "actor": "gastown/polecats/Toast",
  "payload": {
    "session_id": "abc-def-123",
    "role": "gastown/polecats/Toast",
    "topic": "assigned:gt-abc12",
    "cwd": "/path/to/worktree"
  },
  "visibility": "audit"   // or "feed" or "both"
}
```

All event types in the file:
```
sling, hook, unhook, handoff, done, mail, spawn, kill, nudge, boot, halt,
session_start, session_end, session_death, mass_death,
patrol_started, polecat_checked, polecat_nudged, escalation_sent, escalation_acked,
escalation_closed, patrol_complete,
merge_started, merged, merge_failed, merge_skipped,
scheduler_enqueue, scheduler_dispatch, scheduler_dispatch_failed, scheduler_close_retry
```

Query patterns for GSD:
```bash
# Recent merge events for a rig
jq -c 'select(.type == "merged" or .type == "merge_failed")' ~/gt/.events.jsonl | tail -20

# Session starts for a specific polecat bead
jq -c 'select(.type == "session_start" and .payload.topic == "assigned:gt-abc12")' ~/gt/.events.jsonl

# All patrol events
jq -c 'select(.type | startswith("patrol"))' ~/gt/.events.jsonl | tail -50
```

---

## Architecture Patterns

### GSD as External Observer (Not Embedded Agent)

```
GSD scripts
├── gt witness status <rig> --json        → witness health
├── bd list --json --flat --label gt:agent → polecat agent beads
├── bd show <bead-id> --json              → bead detail (AgentFields)
├── gt refinery queue [rig] --json        → merge queue
├── tail ~/gt/.events.jsonl               → event stream
└── gt seance --role polecat --rig <rig>  → predecessor sessions
```

GSD never needs to be a gastown agent (no `BD_ACTOR` unless wrapping `gt done`).

### Polling vs. Event Stream

For real-time monitoring: tail `.events.jsonl` (cheapest, no API).
For current state: `bd show <id> --json` (authoritative, slow ~600ms subprocess).
For bulk listing: `bd list --json --flat` (use `--allow-stale` on bd v0.60+ for speed).

### Bead Description as Structured Storage

GSD-specific fields stored in bead descriptions:
```
gsd_phase: 7
gsd_status: in_progress
gsd_wave: 2
gsd_started_at: 2026-04-12T10:00:00Z
gsd_notes: Wave 1 complete, 3 tasks done
```

Gastown parsers skip unrecognized fields — no conflict risk. Read back with `bd show --json | jq '.[0].description'`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Polecat status monitoring | Custom health checker | `gt witness status --json` + `.events.jsonl` | Witness already does this |
| Merge queue tracking | Custom queue state file | `gt refinery queue --json` + `merged` events | Refinery is the canonical queue |
| Structured bead storage | Separate state DB | Bead description key-value lines | Already git-synced, already indexed |
| Session predecessor lookup | Session log parser | `gt seance --role X --rig Y` | Seance handles cross-account session discovery |
| MR lifecycle tracking | Custom MR state | MR bead status (`bd show <id> --json`) | Beads is the authoritative MR store |

---

## Common Pitfalls

### Pitfall 1: `bd list --json` Without `--flat`
**What goes wrong:** In bd v0.59+, `bd list --json` without `--flat` produces tree-formatted
output that ignores the `--json` flag. JSON is not emitted.
**Why it happens:** Default list format changed to tree in bd v0.59.
**How to avoid:** Always use `bd list --json --flat` in scripts.
**Warning signs:** Parsing fails silently or no results returned.

### Pitfall 2: `bd show --json` Returns an Array
**What goes wrong:** Scripts treat `bd show <id> --json` output as a single object and fail to
parse.
**Why it happens:** `bd show --json` wraps the result in an array even for a single bead.
**How to avoid:** Always parse with `jq '.[0]'`.

### Pitfall 3: Calling `gt done` Without `BD_ACTOR` Set
**What goes wrong:** `gt done` refuses to run if `BD_ACTOR` is set to a non-polecat identity.
**Why it happens:** `done` guards against witness/crew/deacon accidentally calling it.
**How to avoid:** If GSD wraps `gt done` in a skill, set `BD_ACTOR` to the polecat's actor ID,
or ensure GSD runs `gt done` as the polecat (not as a GSD agent identity).

### Pitfall 4: Assuming Witness Exposes a Pull API
**What goes wrong:** Building GSD integration that tries to query the Witness directly
(e.g., HTTP endpoint, Go function call).
**Why it happens:** Witness looks like a daemon.
**How to avoid:** Witness is a Claude agent in tmux, not a Go daemon. Use `gt witness status
--json` for running state, `.events.jsonl` for events.

### Pitfall 5: Seance Fails for Non-Claude Agents
**What goes wrong:** `gt seance --talk <id>` errors: "no agent supports fork session."
**Why it happens:** `--fork-session` is a Claude-specific flag. Non-Claude agent presets have
`SupportsForkSession: false`.
**How to avoid:** Check `config.ListAgentPresets()` / `SupportsForkSession` field. Seance is
only available in Claude Code configurations.

### Pitfall 6: Event File Path Confusion
**What goes wrong:** GSD reads wrong `.events.jsonl` path.
**Why it happens:** The file lives in the town root, not `~/gt/` if the town root is elsewhere.
**How to avoid:** Resolve town root by walking up from cwd looking for `mayor/` directory (same
as gastown's `workspace.FindFromCwd()`). On standard installs, town root is `~/gt`.

### Pitfall 7: Agent Bead `agent_state` in Two Places
**What goes wrong:** GSD reads `issue.agent_state` from `bd list --json` output but gets stale
value.
**Why it happens:** `ResolveAgentState(description, structured)` in beads prefers the description
field over the structured column. The structured column can lag.
**How to avoid:** Always parse `agent_state` from the `description` field using the key-value
parser, not from `issue.agent_state`. Or use `bd show --json` which returns full description.

---

## Code Examples

### Check Witness Health (Phase 7)
```bash
# [VERIFIED: gastown/internal/cmd/witness.go — runWitnessStatus]
gt witness status greenplace --json | jq '{running: .running, session: .session}'
```

### Read Polecat Agent State from Bead (Phase 9)
```bash
# [VERIFIED: gastown/internal/beads/beads_agent.go — AgentFields]
# Must parse from description, not agent_state column
BEAD_JSON=$(bd show gt-abc12 --json | jq '.[0]')
echo "$BEAD_JSON" | jq -r '.description' | grep '^agent_state:' | cut -d' ' -f2
```

### Poll for Merge Completion (Phase 8)
```bash
# [VERIFIED: gastown/internal/events/events.go — TypeMerged]
tail -F ~/gt/.events.jsonl | jq -c --unbuffered 'select(.type == "merged" or .type == "merge_failed")'
```

### List Recent Seance Sessions (Phase 10)
```bash
# [VERIFIED: gastown/internal/cmd/seance.go — discoverSessions]
gt seance --role polecat --rig greenplace --recent 5
# Then: gt seance --talk <session-id> -p "Where did you leave the work?"
```

### List Open MRs in Refinery Queue (Phase 8)
```bash
# [VERIFIED: gastown/internal/refinery/manager.go — Queue()]
gt refinery queue greenplace --json
# Returns: [{"position":1,"mr":{...},"age":"5m ago"}, ...]
```

### Store GSD Phase State in a Bead Description (Phase 9)
```bash
# Create a phase tracking bead
BEAD_ID=$(bd create --title "GSD Phase 7: Witness Integration" \
  --label gsd:phase \
  --description "gsd_phase: 7
gsd_status: in_progress
gsd_wave: 1
gsd_started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | jq -r '.id')

# Update wave progress
CURRENT_DESC=$(bd show "$BEAD_ID" --json | jq -r '.[0].description')
NEW_DESC=$(echo "$CURRENT_DESC" | sed 's/^gsd_wave: .*/gsd_wave: 2/')
bd edit "$BEAD_ID" --description "$NEW_DESC"
```

---

## Environment Availability

| Dependency | Required By | Available | Fallback |
|------------|------------|-----------|----------|
| `gt` CLI | All phases | Assumed (project prerequisite) | None — blocking |
| `bd` CLI | Phase 9 bead queries | Assumed (gastown dep) | None — blocking |
| `tmux` | Witness/Refinery start | Assumed (gastown dep) | None — blocking |
| `jq` | JSON parsing in bash | Standard in gastown plugins | Use Node.js JSON.parse |
| `~/gt/.events.jsonl` | Event stream | Created on first `gt` use | Empty file = no events yet |
| Claude Code (`claude` CLI) | Seance `--fork-session` | Only for Seance Phase 10 | Seance unavailable for non-Claude |

---

## Open Questions

1. **bd version on target machine**
   - What we know: bd v0.59+ requires `--flat`; bd v0.60+ supports `--allow-stale`
   - What's unclear: Exact bd version installed in GSD-Town dev environment
   - Recommendation: Run `bd version` in skill scripts and branch on version, or always use `--flat` (safe for v0.59+)

2. **Town root location**
   - What we know: `.events.jsonl` is in the town root, typically `~/gt/`
   - What's unclear: Whether GSD-Town uses a non-standard town root
   - Recommendation: Use `gt` to detect: `gt status 2>/dev/null | grep root` or walk up from a known rig path

3. **GSD bead label namespace**
   - What we know: GSD can add custom labels to beads freely
   - What's unclear: Whether `gsd:` prefix conflicts with any gastown reserved namespace
   - Recommendation: `gsd:` is safe — gastown only reserves `gt:` prefix labels

4. **Seance in non-Claude agent setups**
   - What we know: `--fork-session` is Claude-only
   - What's unclear: Whether GSD-Town deployments use non-Claude agents
   - Recommendation: Make Phase 10 seance integration conditional on `SupportsForkSession` detection

---

## Sources

### Primary (HIGH confidence — direct Go source read)
- `gastown/internal/witness/manager.go` — Witness lifecycle, IsRunning, IsHealthy, Start/Stop
- `gastown/internal/witness/handlers.go` — Protocol handlers, polecat state detection
- `gastown/internal/witness/protocol.go` — All protocol message types, AgentState constants
- `gastown/internal/refinery/manager.go` — Refinery Queue(), MR discovery from beads
- `gastown/internal/refinery/types.go` — MRStatus, MRPhase, ValidPhaseTransitions
- `gastown/internal/cmd/refinery.go` — CLI commands, QueueItem JSON shape
- `gastown/internal/cmd/done.go` — gt done flow, guard for non-polecat callers
- `gastown/internal/cmd/witness.go` — WitnessStatusOutput JSON shape, all CLI subcommands
- `gastown/internal/cmd/seance.go` — Full seance implementation, session discovery, symlinking
- `gastown/internal/beads/beads.go` — Issue struct, ListOptions, CreateOptions
- `gastown/internal/beads/beads_agent.go` — AgentFields struct, FormatAgentDescription
- `gastown/internal/beads/fields.go` — AttachmentFields, key-value parser pattern
- `gastown/internal/beads/status.go` — AgentState constants, IssueStatus, ResolveAgentState
- `gastown/internal/events/events.go` — Event struct, EventsFile constant, all TypeX constants
- `gastown/internal/channelevents/channelevents.go` — Channel event file-based pub/sub
- `gastown/internal/session/startup.go` — BeaconConfig, FormatStartupBeacon, SessionPayload

---

## Metadata

**Confidence breakdown:**
- Witness monitoring: HIGH — manager.go and handlers.go read directly
- Refinery merging: HIGH — manager.go, types.go, cmd/done.go read directly
- Beads as truth: HIGH — beads.go, fields.go, status.go read directly
- Seance continuity: HIGH — cmd/seance.go read fully (873 lines)
- Event system: HIGH — events.go read fully

**Research date:** 2026-04-12
**Valid until:** Source is stable until gastown releases a breaking API change. Watch for bd version bumps (--flat requirement is v0.59+ specific). Recommend re-verify if bd or gt major version changes.
