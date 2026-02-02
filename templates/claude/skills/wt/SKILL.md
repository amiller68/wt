---
name: wt
description: Worker protocol for wt-managed worktrees. Use when working in a worktree with a .wt/ directory, when you need to signal status (working, blocked, done), or when starting work on a spawned task.
---

# wt Worker Protocol

You are working in a wt-managed worktree.

## Your Task

Read `.wt/task.md` for:
- What you need to do
- Acceptance criteria
- Constraints

## Signaling Status

Update `.wt/status.json` to communicate with the orchestrator:

```json
{
  "status": "working",
  "message": null,
  "updated_at": "2025-02-02T10:30:00Z"
}
```

### Status Values

- `working` - You're actively coding
- `blocked` - You're stuck. Put the reason in `message`
- `question` - You need clarification. Put your question in `message`
- `done` - You've finished. All acceptance criteria met, tests pass

## Workflow

1. Read `.wt/task.md`
2. Set status to `working`
3. Do the work
4. If stuck, set status to `blocked` with explanation
5. When finished, verify acceptance criteria
6. Set status to `done`

## Stay Focused

Only work on what's in `.wt/task.md`. If you discover other issues, note them but don't fix them.
