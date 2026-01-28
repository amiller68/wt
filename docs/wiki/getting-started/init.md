# Initialize a Repo

Set up a repository to use `wt` for worktree management.

## Basic Setup

From your repo root:

```bash
wt init
```

This creates:
- `.worktrees/` directory for worktree storage
- `.claude/` with settings and commands (if using Claude Code)
- `CLAUDE.md` project guide
- Updates `.gitignore`

## What Gets Created

```
your-repo/
├── .worktrees/          # Worktrees live here
├── .claude/
│   ├── settings.json    # Claude Code permissions
│   └── commands/        # Slash commands
├── CLAUDE.md            # Project instructions
└── .gitignore           # Updated to ignore .worktrees
```

## Skip Claude Code Setup

If you just want worktree management without Claude Code integration:

```bash
wt init --minimal
```

## Next Steps

- [Create your first worktree](../usage/worktrees.md)
- [Configure base branches](../usage/configuration.md)
