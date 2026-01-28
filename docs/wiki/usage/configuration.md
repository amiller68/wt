# Configuration

Configure `wt` behavior for your repository.

## Config File

Settings live in `.wt/config` in your repo root:

```bash
# .wt/config
base_branch=main
on_create=./scripts/setup.sh
```

## Options

### base_branch

Default branch for new worktrees:

```bash
base_branch=main
```

When you run `wt new feature`, it branches from `main` (or whatever you set).

### on_create

Script to run after creating a worktree:

```bash
on_create=./scripts/setup.sh
```

Useful for:
- Installing dependencies
- Setting up environment
- Running initial builds

## Per-Worktree Config

Each worktree can have its own `.env` or config. The worktree is a full working copy - configure it like any checkout.

## Example Setup

```bash
# .wt/config
base_branch=develop
on_create=npm install
```

Now `wt new my-feature`:
1. Creates worktree from `develop`
2. Runs `npm install` in the new worktree
