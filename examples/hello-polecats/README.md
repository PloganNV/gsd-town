# Hello Polecats

Minimal example showing GSD-Town dispatching polecats for a 2-plan phase.

## Setup

```bash
# Install GSD-Town
npm install -g gsd-town

# Set up gastown for this example
cd examples/hello-polecats
gsd-town setup --project-name hello-polecats --project-path $(pwd)
```

## Run

```bash
# In Claude Code:
/gsd-execute-phase 1
```

This dispatches 2 polecats in parallel (Wave 1). Each polecat:
1. Reads its plan from bead notes
2. Creates a file
3. Writes results back to bead
4. Calls `gt done`

GSD-Town polls for completion, reconstructs SUMMARY.md from bead notes, and runs verification.

## What You'll See

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GSD ► EXECUTING PHASE 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Wave 1

gastown detected — dispatching to polecats...

◆ Created bead gt-abc12 for plan 01-01
◆ Created bead gt-def34 for plan 01-02
◆ Created convoy hq-cv-xyz for Phase 1
◆ Dispatched polecat for gt-abc12
◆ Dispatched polecat for gt-def34

Polling polecat status (30s interval)...
✓ gt-abc12: done
✓ gt-def34: done

Reconstructing SUMMARY.md from bead notes...
✓ 01-01-SUMMARY.md written
✓ 01-02-SUMMARY.md written

## Wave 1 Complete
```

## Files

- `.planning/ROADMAP.md` — 1 phase, 2 plans
- `.planning/phases/01-hello/01-01-PLAN.md` — Creates hello.txt
- `.planning/phases/01-hello/01-02-PLAN.md` — Creates world.txt
