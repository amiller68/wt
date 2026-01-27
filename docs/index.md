# Agent Instructions

You are an autonomous coding agent working on the `wt` project — a bash-based git worktree manager for parallel Claude Code sessions.

## Project Overview

`wt` simplifies git worktree management and enables multi-agent orchestration via tmux. It lets users create, list, open, and remove worktrees, spawn Claude Code workers in parallel, and merge results back. The entire codebase is pure bash (~2,200 lines) with no build step.

## Key Files and Directories

```
_wt.sh                  # Main entry point and command dispatcher (~1,250 lines)
lib/
├── config.sh           # XDG-compliant config file handling (~/.config/wt/config)
├── setup.sh            # `wt init` — repo initialization, template copying
├── spawn.sh            # Spawn state tracking (JSON in ~/.config/wt/spawned/)
└── tmux.sh             # tmux session/window management for spawned workers
shell/
├── wt.bash             # Bash shell integration + completions
└── wt.zsh              # Zsh shell integration + completions
install.sh              # Curl-based installer (clones to ~/.local/share/worktree)
dev.sh                  # Source this for local development (symlinks + PATH)
test.sh                 # Test runner (creates temp repo, runs tests/)
tests/                  # Test modules (test_basic.sh, test_config.sh, etc.)
templates/              # Templates copied by `wt init` (docs, commands, CLAUDE.md)
agents/                 # Agent orchestration context (INDEX.md, ORCHESTRATION.md)
commands/               # Claude Code slash command definitions
wt.toml                 # Per-repo spawn configuration
manifest.toml           # Version metadata
```

## How to Build, Test, and Run

There is no build step. This is a pure bash project.

**Local development:**
```bash
source ./dev.sh          # Creates symlink, sets PATH, sources shell integration
```

**Run tests:**
```bash
./test.sh                # Runs all test modules in an isolated temp repo
```

Tests create a temporary git repo, set `XDG_CONFIG_HOME` for isolation, and run each `tests/test_*.sh` module. Assert helpers: `assert_eq`, `assert_dir_exists`, `assert_dir_not_exists`.

**CI:** GitHub Actions runs `./test.sh` on both `ubuntu-latest` and `macos-latest`.

## Commands

Core worktree management:
- `wt create <name> [branch]` — create worktree (with `-o` to cd into it)
- `wt list` — list worktrees
- `wt open <name>` — cd to worktree
- `wt remove <pattern>` — remove worktrees (supports globs)
- `wt exit` — leave current worktree

Spawn (multi-agent orchestration):
- `wt spawn <name> [--context <text>] [--auto]` — create worktree + launch Claude in tmux
- `wt ps` — show spawned worker status
- `wt attach` — attach to tmux session
- `wt review <name>` — show diff for spawned worktree
- `wt merge <name>` — merge worktree into current branch
- `wt kill <name>` — kill tmux window

Configuration:
- `wt config base <branch>` — set base branch
- `wt config on-create <cmd>` — set post-create hook
- `wt init` — initialize repo for wt usage

## Code Conventions

**Bash style:**
- `set -e` at top of scripts
- Quote all variables: `"$var"`
- Use `[[ ... ]]` for conditionals
- Errors to stderr: `echo "..." >&2`
- Color constants: `RED`, `GREEN`, `BLUE`, `YELLOW`, `NC`

**Naming:**
- Functions: `snake_case`
- Constants: `UPPER_CASE`
- Locals: `lower_case`
- Command handlers: `handle_<command>()`
- Queries: `is_<state>()`, `get_<data>()`

**Error handling:**
- Color-coded output (RED=error, YELLOW=warning, GREEN=success)
- Exit 1 on failures with descriptive messages
- Guard clauses early in functions

**Git operations:**
- Use `git -C "$path"` instead of cd
- Suppress noise with `2>/dev/null`

**Testing:**
- Add a test module in `tests/test_<feature>.sh` for new functionality
- Tests are sourced by `test.sh` and share the temp repo environment
- Use the existing assert helpers

## Architecture Notes

- The shell function `wt()` (in `shell/wt.bash` or `shell/wt.zsh`) wraps `_wt` and evals its stdout for `cd` operations. Status and error messages go to stderr; only `cd` commands go to stdout.
- Spawn state is per-repo, keyed by MD5 hash of the repo path, stored as JSON in `~/.config/wt/spawned/`.
- tmux session `wt-spawned` holds one window per spawned worker.
- `wt init` copies templates from the install directory's `templates/` into the target repo.
- Config uses XDG paths (`~/.config/wt/config`) with repo-specific keys as absolute paths.

## Workflow

1. **Understand** — Read the task description carefully
2. **Explore** — Search the codebase to understand context and patterns
3. **Plan** — Break down the work into small steps
4. **Implement** — Make changes following existing conventions
5. **Test** — Run `./test.sh` to verify your changes
6. **Commit** — Commit with a clear, descriptive message

## Guidelines

- Follow existing code patterns and conventions
- Make atomic commits (one logical change per commit)
- Add tests for new functionality
- Update documentation if behavior changes
- If blocked, commit what you have and note the blocker
- Dependencies: git, bash/zsh, jq (for spawn features), tmux (for spawn)

## When Complete

Your work will be reviewed and merged by the parent session.
Ensure all tests pass before finishing.
