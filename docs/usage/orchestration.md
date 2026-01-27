# Multi-Agent Orchestration

Use `wt` to orchestrate parallel Claude Code workers for large tasks.

## Quick Start

```bash
# 1. Create an integration worktree for the epic
wt -o create epic-123

# 2. Tell the orchestrating agent what to work on
#    It uses /issues to discover work and /spawn to delegate
claude

# 3. Monitor and manage workers
wt ps                        # check worker status
wt attach                    # watch workers in tmux
wt review <task>             # review completed work
wt merge <task>              # merge into epic branch
```

## Recommended Workflow

### 1. Discovery with `/issues`

The orchestrator starts by understanding the work. Running `/issues` scans the `issues/` directory (or queries an external tracker like Linear via MCP) to find epics and tickets, their status, and what's ready.

### 2. Delegation with `/spawn`

Once the orchestrator understands the work, it decomposes tasks and delegates them:

```bash
wt spawn auth-jwt --context "Implement JWT token generation.

Files to modify:
- src/auth/tokens.ts
- src/auth/config.ts

Requirements:
- Generate and validate JWT tokens
- Support refresh tokens
- Add unit tests

Acceptance criteria:
- All tests pass
- Token flow works end-to-end" --auto
```

Each spawned worker gets its own worktree and runs autonomously.

### 3. Monitor and Merge

```bash
wt ps                    # See status of all workers
wt attach                # Open tmux session to watch progress
wt attach auth-jwt       # Jump to a specific worker
wt review auth-jwt       # Review the diff when done
wt merge auth-jwt        # Merge into your integration branch
wt kill auth-jwt         # Stop a stuck worker
wt remove auth-jwt       # Clean up the worktree
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `wt spawn <name> --context "..." --auto` | Spawn autonomous worker |
| `wt ps` | Check worker status |
| `wt attach [name]` | Watch workers in tmux |
| `wt review <name>` | Review worker's changes |
| `wt merge <name>` | Merge into current branch |
| `wt kill <name>` | Stop a worker |
| `wt remove <name>` | Delete worktree |

## Writing Good Spawn Context

Each spawn should include focused, specific context:

- **One-line summary** of the task
- **Files to modify** (if known)
- **Specific requirements** with enough detail for autonomous work
- **Acceptance criteria** so the worker knows when it's done

## Tips

- Run `/issues` first to understand the full scope before spawning
- Keep tasks independent so workers don't conflict
- Spawn 2-4 workers at a time, merge as they complete
- Include specific file paths when you know them
- Set clear acceptance criteria
- Use `wt attach` to monitor progress
