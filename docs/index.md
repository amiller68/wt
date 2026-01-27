# Agent Instructions

You are working on `wt` — a bash CLI for managing git worktrees, designed for parallel Claude Code sessions. Pure bash, no build step.

## Key Files

```
_wt.sh              # Main entry point and command dispatcher (~1250 lines)
lib/
├── config.sh       # wt.toml parsing (section.key lookup, arrays)
├── init.sh         # wt init — repo initialization, template copying
├── spawn.sh        # Spawn state tracking (JSON in ~/.config/wt/spawned/)
└── tmux.sh         # tmux session/window management for spawned workers
shell/
├── wt.bash         # Bash shell integration + completions
└── wt.zsh          # Zsh shell integration + completions
templates/          # Files copied by wt init (docs, commands, CLAUDE.md)
test.sh             # Test runner with assert helpers
tests/              # Test modules (test_basic.sh, test_config.sh, etc.)
manifest.toml       # Version (semver, currently 0.3.0)
install.sh          # curl-based installer
dev.sh              # Source this to use local wt instead of installed version
```

## Development

```bash
source ./dev.sh     # Use local wt instead of installed version
./test.sh           # Run all tests (isolated temp repo, XDG isolated)
```

There is no build step, linter, or formatter. The only check is `./test.sh`.

## Commands

| Command | Purpose |
|---------|---------|
| `create` | Create a new worktree branch |
| `list` | List worktrees (local or --all) |
| `open` | cd into a worktree (--all opens tabs) |
| `remove` | Remove worktree(s), supports glob patterns |
| `exit` | Remove current worktree and return to base |
| `config` | Get/set base branch, on-create hooks |
| `spawn` | Create worktree + launch Claude in tmux |
| `ps` | Show status of spawned sessions |
| `attach` | Attach to a tmux spawn session |
| `review` | Show diff for spawned worktree |
| `merge` | Merge spawned work into current branch |
| `kill` | Kill a spawned tmux window |
| `init` | Initialize wt config for a repo |
| `health` | Check dependencies and config |
| `update` | Self-update from GitHub |

## Architecture

- **Worktrees** live in `.worktrees/` (auto-excluded via `.git/info/exclude`)
- **Config** stored in `~/.config/wt/config` (XDG-compliant)
- **Spawn state** tracked as JSON in `~/.config/wt/spawned/<hash>.json` (requires `jq`)
- **tmux** manages spawned sessions: single `wt-spawned` session, one window per task
- **Shell integration**: wrapper function evals `cd` commands from stdout
- **stdout** is reserved for eval-able output — all user-facing messages go to stderr

## Conventions

- Functions: `snake_case`, command handlers: `handle_<command>()`
- Errors to stderr, color-coded (`RED`, `GREEN`, `BLUE`, `YELLOW`)
- Quote all variables, use `[[ ... ]]` for conditionals
- Add tests in `tests/test_<feature>.sh` for new functionality
- `set -e` in test scripts

## Testing

- **Run:** `./test.sh`
- **Structure:** `tests/test_*.sh` modules sourced by test.sh
- **Helpers:** `assert_eq`, `assert_dir_exists`, `assert_dir_not_exists`
- **Isolation:** Creates temp git repo with origin/main, XDG isolation
- **Modules:** test_basic, test_nested, test_config, test_exit, test_hooks, test_open_all, test_spawn

## Workflow

1. Read the task description
2. Explore the codebase for context and patterns
3. Implement following existing conventions
4. Run `./test.sh`
5. Commit with a clear message

## When Complete

Your work will be reviewed and merged by the parent session.
Ensure all tests pass before finishing.
