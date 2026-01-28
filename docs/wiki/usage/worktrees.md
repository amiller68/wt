# Working with Worktrees

Core commands for creating and managing worktrees.

## Create a Worktree

```bash
wt new my-feature
```

Creates a new worktree at `.worktrees/my-feature` with a branch named `my-feature`.

### From a Specific Branch

```bash
wt new my-feature --from main
wt new my-feature --from origin/develop
```

## Open a Worktree

```bash
wt open my-feature
```

With shell integration, this `cd`s into the worktree. Without it, prints the path.

## List Worktrees

```bash
wt list
```

Shows all worktrees with their branches and status.

## Delete a Worktree

```bash
wt rm my-feature
```

Removes the worktree directory. The branch remains (delete separately with `git branch -d`).

### Force Delete

```bash
wt rm my-feature --force
```

Removes even if there are uncommitted changes.

## Typical Workflow

```bash
# Start new work
wt new fix-login-bug

# Work on it...
# (commits, pushes, PR)

# Clean up when done
wt rm fix-login-bug
```
