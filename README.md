# wt

[![Tests](https://github.com/amiller68/worktree/actions/workflows/test.yml/badge.svg)](https://github.com/amiller68/worktree/actions/workflows/test.yml)

Git worktree manager for running parallel Claude Code sessions.

## Features

- **Simple commands** - Create, list, open, and remove worktrees with short commands
- **Auto-isolation** - Worktrees stored in `.worktrees/` (automatically git-ignored)
- **Configurable base branch** - Set per-repo or global default base branch
- **On-create hooks** - Run setup commands automatically after worktree creation
- **Shell integration** - Tab completion for commands and worktree names
- **Nested paths** - Supports branch names like `feature/auth/login`
- **Self-updating** - Run `wt update` to get the latest version
- **Multi-agent workflow** - Spawn parallel Claude Code sessions with tmux integration

## Install

```bash
curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash
```

Restart your shell after installing, or run:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Commands

| Command | Description |
|---------|-------------|
| `wt create <name> [branch]` | Create a worktree with a new branch |
| `wt create <name> -o` | Create and cd into the worktree |
| `wt create <name> --no-hooks` | Create without running on-create hook |
| `wt open <name>` | cd into an existing worktree |
| `wt open --all` | Open all worktrees in new terminal tabs |
| `wt list` | List worktrees in `.worktrees/` |
| `wt list --all` | List all git worktrees |
| `wt remove <pattern>` | Remove worktree(s) matching pattern (supports glob) |
| `wt exit [--force]` | Exit current worktree (removes it, returns to base) |
| `wt health` | Show terminal detection and dependency status |
| `wt config` | Show config for current repo |
| `wt config base <branch>` | Set base branch for current repo |
| `wt config base --global <branch>` | Set global default base branch |
| `wt config on-create <cmd>` | Set on-create hook for current repo |
| `wt config on-create --unset` | Remove on-create hook |
| `wt config --list` | List all configuration |
| `wt spawn <name> [options]` | Create worktree + launch Claude in tmux |
| `wt spawn --context <text>` | Provide task context for Claude |
| `wt spawn --auto` | Auto-start Claude with full prompt |
| `wt ps` | Show status of spawned sessions |
| `wt attach [name]` | Attach to tmux session (optionally to specific window) |
| `wt review <name>` | Show diff for parent review |
| `wt merge <name>` | Merge reviewed worktree into current branch |
| `wt kill <name>` | Kill a running tmux window |
| `wt init [--force] [--backup] [--audit]` | Initialize wt.toml, docs/, issues/, and .claude/ |
| `wt update` | Update wt to latest version |
| `wt update --force` | Force update (reset to remote) |
| `wt version` | Show version |
| `wt which` | Show path to wt script |

## Quick Start

```bash
cd ~/projects/my-app
wt create feature-auth -o    # Creates worktree, cd's into it
claude                       # Start Claude Code in isolation
```

Open a second terminal and do the same — both sessions work independently on their own branches.

## Guides

- [Working with Worktrees](docs/usage/worktrees.md) — Create, open, remove, glob patterns, terminal tabs
- [Configuration and Hooks](docs/usage/configuration.md) — Base branch, config file format, on-create hooks
- [Setting Up a Repo with `wt init`](docs/usage/init.md) — Bootstrap docs, commands, and permissions
- [Multi-Agent Orchestration](docs/usage/orchestration.md) — Spawn parallel Claude workers with tmux
- [Shell Integration](docs/usage/shell-integration.md) — Tab completion, how `-o` works, `wt which`

## Development

To test local changes without affecting your installed version:

```bash
source ./dev.sh
```

This only affects the current terminal session. Open a new terminal to go back to your installed version.

## Testing

Run the test suite:

```bash
./test.sh
```

Tests run on both Ubuntu and macOS via GitHub Actions.

## Updating

```bash
wt update          # Pull latest changes
wt update --force  # Force reset to remote (discards local changes)
```

## Uninstall

```bash
rm -rf ~/.local/share/worktree
rm ~/.local/bin/_wt
# Remove source lines from ~/.bashrc and ~/.zshrc
```

## Requirements

- Git
- Bash or Zsh

**For `wt spawn` (optional):**
- `tmux` - Terminal multiplexer
- `jq` - JSON processor
- `claude` CLI
- `gh` CLI (for PR creation)

## License

MIT
