# Agent Instructions

You are working on `wt` — a bash CLI for managing git worktrees, designed for parallel Claude Code sessions. Pure bash, no build step.

## Key Files

```
_wt.sh              # Main entry point and command dispatcher (~1255 lines)
lib/
├── config.sh       # TOML config parsing (wt.toml, ~/.config/wt/config)
├── init.sh         # wt init — repo initialization, template copying
├── spawn.sh        # Spawn state tracking (JSON in ~/.config/wt/spawned/)
└── tmux.sh         # tmux session/window management for spawned workers
shell/
├── wt.bash         # Bash shell integration + completions
└── wt.zsh          # Zsh shell integration + completions
templates/          # Files copied by wt init (docs, commands, CLAUDE.md)
install.sh          # Installation script (clones to ~/.local/share/worktree)
test.sh             # Test runner (isolated temp repo, XDG isolated)
tests/              # Test modules (test_basic.sh, test_config.sh, etc.)
manifest.toml       # Version (semver, currently 0.3.0)
wt.toml             # Per-repo spawn configuration
```

## Development

```bash
source ./dev.sh     # Use local wt instead of installed version
./test.sh           # Run all tests
```

## Architecture

Three-layer design:

1. **Core script (`_wt.sh`)** — All business logic: repo detection, worktree CRUD, config, spawn orchestration
2. **Library modules (`lib/`)** — Pluggable functionality: TOML parsing, tmux integration, spawn state, init
3. **Shell integration (`shell/`)** — Bash/zsh wrappers enabling `cd` via eval, plus tab completion

Key design decisions:
- Worktrees live in `.worktrees/` (auto-excluded from git)
- Single tmux session (`wt-spawned`) for all spawn windows
- JSON state files in `~/.config/wt/spawned/` for spawn tracking
- `wt.toml` for per-repo config (committed), `~/.config/wt/config` for user config
- No external deps for core features (git + bash/zsh only); tmux + jq + claude CLI for spawn

## Conventions

- Functions: `snake_case`, command handlers: `handle_<command>()`
- Errors to stderr, color-coded (`RED`, `GREEN`, `BLUE`, `YELLOW`)
- stdout is reserved for eval-able output (e.g. `cd` commands the shell wrapper evals)
- Quote all variables, use `[[ ... ]]` for conditionals
- Add tests in `tests/test_<feature>.sh` for new functionality
- `set -e` is used — functions should fail early on errors

## Commands Reference

| Command | Handler | Description |
|---------|---------|-------------|
| `create` | `create_worktree()` | Create worktree from base branch |
| `list` | `list_worktrees()` | List worktrees |
| `remove` | `remove_worktree()` | Remove worktree (supports globs) |
| `open` | `open_worktree()` | Output cd command for shell eval |
| `exit` | `exit_worktree()` | Remove current worktree, return to base |
| `spawn` | `handle_spawn()` | Create worktree + launch Claude in tmux |
| `ps` | `handle_ps()` | Show spawned worker status |
| `attach` | `handle_attach()` | Attach to tmux session |
| `review` | `handle_review()` | Show diff for review |
| `merge` | `handle_merge()` | Merge worktree branch into current |
| `kill` | `handle_kill()` | Kill tmux window |
| `config` | `handle_config()` | Manage config (base branch, hooks) |
| `init` | `handle_init()` | Initialize repo with templates |

## Testing

Tests use a custom bash framework in `test.sh`:
- Creates an isolated temp git repo with `origin/main`
- Each test module in `tests/` is sourced and run sequentially
- Assertion helpers: `assert_eq`, `assert_dir_exists`, `assert_dir_not_exists`
- XDG dirs are isolated to temp directory

Run tests before committing any changes:
```bash
./test.sh
```

## Workflow

1. Read the task description (check `.claude-task` if it exists)
2. Explore the codebase for context and patterns
3. Implement following existing conventions
4. Run `./test.sh`
5. Commit with a clear message

## When Complete

Your work will be reviewed and merged by the parent session.
Ensure all tests pass before finishing.
