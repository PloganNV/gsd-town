# Phase 6: Mayor Delegation - Research

**Researched:** 2026-04-12
**Domain:** Gastown Mayor / Convoy programmatic dispatch
**Confidence:** HIGH (all findings from gastown source code, read directly)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MAYOR-01 | Mayor receives a convoy of beads and dispatches polecats autonomously | Convoy launch dispatches Wave 1 immediately; daemon heartbeat dispatches subsequent waves. Mayor is NOT the dispatcher — the convoy+daemon system is. |
| MAYOR-02 | execute-phase.md delegates to Mayor via convoy handoff (replaces per-plan gt sling) | `gt convoy stage --launch` is the entry point. GSD hands a convoy ID to this command, not to the Mayor directly. |
| MAYOR-03 | Mayor signals GSD orchestrator on convoy completion (replaces polling loop) | `gt convoy watch <convoy-id> --nudge --addr <gsd-agent>` is the push-notification path. Alternatively: poll `gt convoy status <id> --json` and check `.status == "closed"`. |
</phase_requirements>

---

## Summary

The Mayor is a Claude session — not an API, not a message bus, not a programmatic dispatch engine. It is an autonomous LLM agent running in a tmux session (or ACP headless mode) that *reads mail and nudges* and *decides what to sling*. You cannot hand the Mayor a convoy via a function call or CLI flag. The Mayor receives information about work through mail (`gt mail send mayor/ ...`) or nudge (`gt nudge mayor ...`), then the Mayor decides to run `gt convoy status` and `gt sling` itself.

The correct abstraction for "hand gastown a convoy and let it drive" is **not the Mayor** — it is the **convoy + daemon system**:

1. GSD creates beads (`bd create`) for each plan.
2. GSD creates or stages a convoy (`gt convoy create` or `gt convoy stage`) grouping those beads.
3. GSD launches the convoy (`gt convoy launch <convoy-id>`) — this atomically transitions status to `open` and dispatches Wave 1 polecats via `gt sling`.
4. The **daemon patrol** (`check-convoy-completion` step in every heartbeat) auto-dispatches subsequent waves as beads complete, and auto-closes the convoy when all beads are done.
5. GSD gets the completion signal via `gt convoy watch <convoy-id> --nudge --addr <gsd-agent>` (push) or by polling `gt convoy status <id> --json` (pull).

The Mayor *can* be looped in as a strategic coordinator — e.g., send it mail saying "convoy hq-cv-xyz launched, please coordinate" — but it is not the mechanical dispatch path.

**Primary recommendation:** Use `gt convoy stage --launch` to hand gastown a convoy. Subscribe to completion via `gt convoy watch --nudge`. The Mayor is optional overhead for Phase 6 — the convoy+daemon system is the right entry point.

---

## What the Mayor Actually Is

[VERIFIED: gastown/internal/cmd/mayor.go, gastown/internal/mayor/manager.go]

The Mayor has two runtime modes:

| Mode | How started | How it receives work |
|------|------------|----------------------|
| **TMUX** (default) | `gt mayor start` → detached tmux session running Claude | Nudge injected into tmux pane via `tmux send-keys`; mail in its mailbox |
| **ACP** (headless) | `gt mayor acp` → stdin/stdout connected, no tmux | Startup prompt piped in; ACP propeller polls for queued mail |

In both modes, the Mayor is an LLM session. It does not have a programmatic "accept convoy" API. Work arrives as natural language text (nudges or mail). The Mayor then issues `gt` CLI commands itself.

`gt mayor attach` attaches your terminal to the tmux session — it is a human-facing debugging tool, not a programmatic interface.

---

## Convoy Dispatch Pipeline

[VERIFIED: gastown/internal/cmd/convoy_launch.go, convoy_stage.go, scheduler_convoy.go, scheduler.go]

### Lifecycle of a convoy from GSD's perspective

```
1. bd create --title "Plan: X" --type task --rig <rig>   → bead ID (e.g., gt-abc)
   (repeat for each plan)

2. gt convoy stage "Phase 6 plans" gt-abc gt-def gt-ghi  → staged convoy (hq-cv-xyz)
   OR
   gt convoy create "Phase 6 plans" gt-abc gt-def gt-ghi → open convoy immediately

3. gt convoy launch hq-cv-xyz
   → transitions status: staged_ready → open
   → calls dispatchWave1(): runs `gt sling <bead-id> <rig>` for each Wave 1 bead
   → stdout: "Subsequent waves will be dispatched automatically by the daemon"

4. Daemon patrol heartbeat (every ~10 min):
   → step: check-convoy-completion
   → if all tracked beads closed: closes convoy, calls notifyConvoyCompletion()
   → notifyConvoyCompletion sends mail to --owner and --notify addresses
   → if convoy.notify_on_complete config is true: nudges Mayor session too

5. GSD completion signal (two options — see below)
```

### Wave dispatch mechanism

Wave 1 is dispatched synchronously by `gt convoy launch`. **Subsequent waves are dispatched by the daemon**, not by anything GSD needs to orchestrate. The daemon's `check-convoy-completion` patrol step handles this:
- Checks all open convoys periodically
- As beads complete (status → `closed`), the daemon feeds next-wave beads
- The stranded convoy scan detects and repairs stuck convoys

[VERIFIED: gastown/internal/cmd/convoy_launch.go line 261: "Subsequent waves will be dispatched automatically by the daemon as tasks complete."]

---

## Completion Signal Options

[VERIFIED: gastown/internal/cmd/convoy_watch.go, convoy.go notifyConvoyCompletion()]

### Option A: Push notification via `gt convoy watch` (RECOMMENDED)

```bash
# Register GSD as a watcher before launching
gt convoy watch hq-cv-xyz --nudge --addr <gsd-identity>

# OR: watch with mail
gt convoy watch hq-cv-xyz --addr <gsd-identity>
```

When the convoy closes, gastown calls `notifyConvoyCompletion()` which:
1. Sends mail or nudge to every address in the watcher list
2. If `convoy.notify_on_complete` is set in town config: also nudges the Mayor session

The `--nudge` flag sends a lightweight nudge (no Dolt commit). Mail sends a permanent bead message.

For GSD's purposes, the watcher address should be a GSD-controlled identity that GSD polls or that triggers a callback. Since GSD runs as a bash/Node.js process (not a tmux agent), the practical implementation is:
- Register a callback hook or use a named file/pipe as the signal
- OR: fall back to polling (Option B) — simpler to implement correctly

### Option B: Polling `gt convoy status --json` (SIMPLER)

```bash
gt convoy status hq-cv-xyz --json
```

Returns JSON:
```json
{
  "id": "hq-cv-xyz",
  "title": "Phase 6 plans",
  "status": "closed",          // "open" | "closed" | "staged_ready" | "staged_warnings"
  "owned": false,
  "lifecycle": "system-managed",
  "tracked": [...],
  "completed": 3,
  "total": 3
}
```

Poll until `status == "closed"`. This replaces the current per-plan 30-second polling loop with a single convoy-level check.

[VERIFIED: gastown/internal/cmd/convoy.go lines 1808-1837 — JSON schema confirmed]

---

## How `gt sling` Relates to the Mayor

[VERIFIED: gastown/internal/cmd/sling.go, sling_dispatch.go]

`gt sling <bead> <rig>` is the atomic dispatch primitive. It:
1. Spawns a polecat in the target rig
2. Hooks the bead to the polecat
3. Starts the polecat's tmux session
4. Auto-creates a convoy for the bead (unless `--no-convoy` or already tracked)

When a human runs `gt sling`, it goes **directly to the rig** — it does NOT go through the Mayor. The Mayor is not in the dispatch critical path at all.

`gt convoy launch` calls `dispatchTaskDirect()` which runs `gt sling <bead-id> <rig>` as a subprocess for each Wave 1 task. The Mayor never touches this code path.

The Mayor gets notified *after* polecats complete (via `notifyMayorSlotOpen()` in witness/handlers.go), so it can decide what to sling next. But for a GSD-managed convoy, GSD doesn't need the Mayor to make that decision — the convoy's wave structure already encodes the sequencing.

---

## Mayor's Role in Convoy Coordination

[VERIFIED: gastown/internal/witness/handlers.go, gastown/internal/cmd/convoy.go]

When a polecat finishes, the Witness calls `notifyMayorSlotOpen()`:
```
SLOT_OPEN: <rig>/<polecat> completed (exit=COMPLETED) — slot available.
```
This nudges the Mayor tmux session. The Mayor can then decide to run `gt polecat list` and `gt sling` the next bead.

This is the "Mayor as strategic coordinator" role — useful for unstructured work where a human-equivalent needs to decide what to do next. For GSD's case (convoy with a predetermined DAG of tasks), the convoy+daemon system handles sequencing automatically without Mayor involvement.

**Bottom line:** For Phase 6, GSD does not need to communicate with the Mayor at all. GSD creates a convoy, launches it, and waits for a `closed` signal. If desired, GSD can mail the Mayor as a courtesy notification that work has started, but it is not required for autonomous operation.

---

## Standard Stack

[VERIFIED: gastown source code, read directly]

| Command | Purpose | Notes |
|---------|---------|-------|
| `gt convoy stage <title> <bead-id...>` | Stage a convoy (validates DAG, generates waves) | Use `--json` for machine-readable stage result including convoy_id |
| `gt convoy stage <title> <bead-id...> --launch` | Stage and immediately launch | Single command for GSD's dispatch path |
| `gt convoy launch <convoy-id>` | Launch a staged convoy | Dispatches Wave 1 synchronously |
| `gt convoy watch <convoy-id> --nudge --addr <addr>` | Subscribe to completion (push) | Fire-and-forget; nudge when convoy closes |
| `gt convoy status <convoy-id> --json` | Poll convoy status (pull) | Check `.status == "closed"` |
| `gt convoy check` | Run daemon's completion check manually | Useful for testing; daemon runs this automatically |
| `gt mail send mayor/ -s <subject> -m <body>` | Send work notification to Mayor | Optional — Mayor reads mail and decides what to do |
| `gt nudge mayor -m <message>` | Lightweight nudge to Mayor session | For immediate attention; no Dolt commit |

### Stage result JSON (`gt convoy stage --json`)

```json
{
  "status": "staged_ready",      // or "staged_warnings", "error"
  "convoy_id": "hq-cv-xyz",
  "restaged": false,
  "validation_bead_id": "...",   // optional capstone validation bead
  "errors": [],
  "warnings": [],
  "waves": [
    {
      "number": 1,
      "tasks": [{"id": "gt-abc", "title": "...", "type": "task", "rig": "gastown"}]
    }
  ],
  "gated": [],
  "tree": []
}
```

---

## Architecture Patterns

### Pattern 1: GSD convoy handoff (recommended for MAYOR-02)

```bash
# In execute-phase.md dispatch block:

# 1. Create beads for each plan
BEAD_IDS=()
for plan in "${PLANS[@]}"; do
  BEAD_ID=$(bd create --title "$plan" --type task --rig "$RIG" --json | jq -r '.id')
  BEAD_IDS+=("$BEAD_ID")
done

# 2. Stage and launch convoy (single command)
RESULT=$(gt convoy stage "Phase $PHASE_NUM: $PHASE_NAME" "${BEAD_IDS[@]}" --launch --json)
CONVOY_ID=$(echo "$RESULT" | jq -r '.convoy_id')

# 3. Subscribe for completion notification
gt convoy watch "$CONVOY_ID" --nudge --addr "gsd-orchestrator/"
# OR: store $CONVOY_ID and poll in the wait loop
```

### Pattern 2: Polling completion (replaces current 30-second per-plan loop)

```bash
# Replace current polling loop with convoy-level check
wait_for_convoy() {
  local convoy_id="$1"
  local timeout=3600  # 1 hour
  local elapsed=0
  local interval=60   # check every 60 seconds

  while [ $elapsed -lt $timeout ]; do
    STATUS=$(gt convoy status "$convoy_id" --json | jq -r '.status')
    if [ "$STATUS" = "closed" ]; then
      echo "Convoy $convoy_id complete"
      return 0
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  echo "Timeout waiting for convoy $convoy_id"
  return 1
}
```

### Pattern 3: Optional Mayor notification

```bash
# After launching convoy (informational only — not required for dispatch)
gt mail send mayor/ \
  -s "GSD Phase $PHASE_NUM launched: convoy $CONVOY_ID" \
  -m "GSD has launched convoy $CONVOY_ID for Phase $PHASE_NUM ($PHASE_NAME). $BEAD_COUNT beads across $RIG_COUNT rigs. Monitor: gt convoy status $CONVOY_ID"
```

### Anti-patterns

- **Trying to "hand the Mayor a convoy" programmatically**: The Mayor has no API. Mail it a notification if desired, but it is not the dispatch entry point.
- **Calling `gt sling` per plan**: This is what Phase 6 replaces. The convoy system handles dispatch + sequencing automatically.
- **Expecting the Mayor to advance waves**: The daemon does this. Mayor only receives `SLOT_OPEN` nudges and may decide to sling next — but for GSD convoys the DAG structure handles this.
- **Building a watcher daemon to receive nudges**: GSD is not a gastown agent. For the completion signal, polling `gt convoy status --json` is simpler and more robust than trying to build a nudge receiver.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Wave sequencing | Custom dependency resolver | `gt convoy stage` computes waves from bead deps |
| Polecat dispatch | Per-plan `gt sling` calls | `gt convoy launch` dispatches Wave 1; daemon handles subsequent waves |
| Convoy completion detection | Counting closed beads yourself | `gt convoy status --json` — `.status == "closed"` |
| Completion notification | Polling loop per bead | `gt convoy watch --nudge` for push; single convoy poll for pull |
| Mayor communication | Custom IPC | `gt mail send mayor/` or `gt nudge mayor` |

---

## Common Pitfalls

### Pitfall 1: Mistaking the Mayor for the dispatch engine

**What goes wrong:** Building code that sends convoy IDs to the Mayor and expects the Mayor to dispatch polecats. The Mayor is an LLM — it may or may not choose to act, and there is no way to programmatically confirm it did.

**Why it happens:** The Mayor is described as the "Chief of Staff for cross-rig coordination" which sounds like it owns dispatch.

**How to avoid:** Use `gt convoy launch` for dispatch. If you want the Mayor involved, mail it as a notification after launch — but it is not in the critical path.

**Warning signs:** Looking for a "gt mayor dispatch" or "gt mayor convoy" command (none exists).

### Pitfall 2: Assuming convoy watch delivers to GSD reliably

**What goes wrong:** Registering GSD as a watcher via `gt convoy watch` and never receiving the nudge because GSD is not a tmux agent.

**Why it happens:** Gastown's nudge system (`t.NudgeSession`) targets tmux sessions. If GSD's "identity" doesn't have a tmux session, the nudge falls back to mail — which still requires GSD to poll its mailbox.

**How to avoid:** Use polling (`gt convoy status --json`) as the primary completion mechanism for Phase 6. It is simpler and does not require GSD to be a gastown agent. The push notification path requires GSD to have a named mailbox identity in gastown's mail system.

### Pitfall 3: Launching without staging DAG validation

**What goes wrong:** Calling `gt convoy create` (which bypasses staging) and having polecats start in the wrong order because wave structure was not computed.

**How to avoid:** Use `gt convoy stage <title> <beads...> --launch` which validates the DAG, computes waves, and launches in one command. The stage step catches orphaned deps, rig availability, and other issues before dispatch.

### Pitfall 4: Not knowing the convoy ID before polecats complete

**What goes wrong:** GSD loses track of which convoy it launched (state not persisted) and can't poll for completion.

**How to avoid:** Store the convoy ID in STATE.md or a phase-level state file immediately after `gt convoy stage --json` returns. The JSON response includes `convoy_id`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The daemon auto-dispatches subsequent waves (not the Mayor, not GSD) | Convoy Dispatch Pipeline | If wrong, GSD would need to manually call `gt convoy launch` or `gt sling` for each wave — significant rework |
| A2 | `gt convoy watch --nudge` falls back to mail if target has no tmux session | Completion Signal Options | If wrong, we'd lose completion signals silently; polling fallback covers this |
| A3 | `gt convoy stage --json` returns `convoy_id` immediately | Standard Stack | Verified in source (convoy_stage.go StageResult struct has `convoy_id`); [VERIFIED] |

---

## Open Questions

1. **Does GSD have a gastown mail identity?**
   - What we know: `gt convoy watch --addr <addr>` requires a valid gastown address. GSD does not currently register itself as a gastown agent.
   - What's unclear: Whether GSD needs to register an identity or whether polling is sufficient for Phase 6.
   - Recommendation: Use polling for Phase 6. Defer push notification to a future phase when GSD has a gastown identity.

2. **What rig should GSD create beads in?**
   - What we know: `bd create --rig <rig>` assigns a bead to a rig. The bead prefix is derived from the rig prefix.
   - What's unclear: Phase 6 plans don't specify multi-rig targeting. Single-rig dispatch is simpler.
   - Recommendation: Use the configured default rig from `gt config show` or the GSD-Town `~/.gsd-town/settings.json`.

3. **Should the Mayor be notified at all in Phase 6?**
   - What we know: Notifying the Mayor is entirely optional. The convoy+daemon system works without Mayor involvement.
   - Recommendation: Skip Mayor notification for Phase 6. Keep it simple: GSD → convoy → daemon → GSD. Mayor delegation can be added in a follow-on if multi-rig coordination is needed.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gt CLI | All convoy operations | [ASSUMED — should be installed from Phase 1-5] | gastown 1.x | Must be installed; no fallback |
| bd CLI | Bead creation | [ASSUMED] | beads 1.x | Must be installed; no fallback |
| Dolt server | Bead database backend | [ASSUMED] | — | `gt mayor attach` auto-starts it |
| tmux | Polecat sessions | [ASSUMED] | >=3.0 | No fallback for polecat dispatch |
| Daemon (gt patrol) | Subsequent wave dispatch | [ASSUMED] | — | Without daemon, only Wave 1 dispatches; `gt convoy check` can be called manually |

Note: This phase is GSD-Town code changes only. These dependencies were verified in Phases 1-5. No new environment probing needed at research time.

---

## Validation Architecture

Test commands for Phase 6 changes (execute-phase.md dispatch block rewrite):

| Behavior | Test Type | Command | Notes |
|----------|-----------|---------|-------|
| `gt convoy stage --json` parses correctly | unit | Parse stage result JSON in test env | Mock `gt` binary |
| `gt convoy status --json` returns closed status | unit | Parse status JSON in test env | Mock `gt` binary |
| Convoy ID persisted to STATE.md after launch | integration | Run dispatch block; check STATE.md | Requires test gastown town |
| Polling loop terminates on `status=closed` | unit | Unit test wait_for_convoy with mock | Mock gt output |

---

## Sources

### Primary (HIGH confidence — read from source)
- `/Users/laul_pogan/Source/gastown/internal/cmd/mayor.go` — Mayor command structure, tmux/ACP modes, no dispatch API
- `/Users/laul_pogan/Source/gastown/internal/mayor/manager.go` — Mayor.Start(), StartTMUX(), StartACP() — confirms Mayor is session-based, not an API
- `/Users/laul_pogan/Source/gastown/internal/cmd/convoy_launch.go` — dispatchWave1(), dispatchTaskDirect() = `gt sling <bead> <rig>`, daemon auto-dispatches subsequent waves
- `/Users/laul_pogan/Source/gastown/internal/cmd/convoy_stage.go` — StageResult JSON schema with convoy_id, waves, status
- `/Users/laul_pogan/Source/gastown/internal/cmd/convoy_watch.go` — `gt convoy watch --nudge`, watcher list in bead description
- `/Users/laul_pogan/Source/gastown/internal/cmd/convoy.go` — notifyConvoyCompletion(), notifyMayorSession(), convoy status JSON schema
- `/Users/laul_pogan/Source/gastown/internal/cmd/sling_dispatch.go` — executeSling() — confirms sling goes directly to rig, not through Mayor
- `/Users/laul_pogan/Source/gastown/internal/cmd/sling.go` — sling command docs confirming Mayor is a target, not a coordinator
- `/Users/laul_pogan/Source/gastown/internal/cmd/scheduler_convoy.go` — runConvoySlingByID(), runConvoyScheduleByID()
- `/Users/laul_pogan/Source/gastown/internal/cmd/scheduler.go` — schedulerRunCmd, dispatchScheduledWork() called by daemon heartbeat
- `/Users/laul_pogan/Source/gastown/internal/witness/handlers.go` — notifyMayorSlotOpen() — Mayor receives SLOT_OPEN after polecat completion
- `/Users/laul_pogan/Source/gastown/internal/cmd/mountain.go` line 265 — "ConvoyManager will feed subsequent waves"

---

## Metadata

**Confidence breakdown:**
- Mayor architecture: HIGH — read from source, no ambiguity
- Convoy dispatch pipeline: HIGH — read from source, confirmed end-to-end
- Completion signal: HIGH — convoy_watch.go and notifyConvoyCompletion() read directly
- Wave auto-dispatch by daemon: HIGH — confirmed by convoy_launch.go output text and mountain.go

**Research date:** 2026-04-12
**Valid until:** 2026-07-12 (stable codebase, 90-day window)
