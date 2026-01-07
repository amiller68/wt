# wt

Git worktree manager for running parallel Claude Code sessions.

## Install

```bash
curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash
```

Restart your shell after installing.

## Usage

```bash
wt create <name> [branch]   # Create worktree (new branch from origin/dev by default)
wt -o create <name>         # Create and cd into worktree
wt open <name>              # cd into existing worktree
wt list                     # List all worktrees
wt remove <name>            # Remove a worktree
wt cleanup                  # Remove all worktrees
wt update                   # Update wt to latest version
wt version                  # Show version
```

## How it works

Worktrees are stored in `.worktrees/` inside your repo (auto-added to `.git/info/exclude`).

```
my-repo/
├── .worktrees/
│   ├── feature-a/    # wt create feature-a
│   └── feature-b/    # wt create feature-b
└── ...
```

## Example workflow

```bash
cd ~/projects/my-app
wt -o create feature-auth    # Creates worktree, cd's into it
claude                       # Start Claude Code in the worktree
```

Meanwhile in another terminal:
```bash
cd ~/projects/my-app
wt -o create fix-bug-123
claude
```

Both instances work independently with their own branches.

## Testing

Run the test suite:

```bash
./test.sh
```

Tests cover create, list, open, remove, and nested path handling.
