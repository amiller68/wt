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
| `wt list` | List worktrees in `.worktrees/` |
| `wt list --all` | List all git worktrees |
| `wt remove <pattern>` | Remove worktree(s) matching pattern (supports glob) |
| `wt cleanup` | Remove all worktrees |
| `wt config` | Show config for current repo |
| `wt config base <branch>` | Set base branch for current repo |
| `wt config base --global <branch>` | Set global default base branch |
| `wt config on-create <cmd>` | Set on-create hook for current repo |
| `wt config on-create --unset` | Remove on-create hook |
| `wt config --list` | List all configuration |
| `wt update` | Update wt to latest version |
| `wt update --force` | Force update (reset to remote) |
| `wt version` | Show version |
| `wt which` | Show path to wt script |

## Usage

### Create a worktree and start working

```bash
cd ~/projects/my-app
wt create feature-auth -o    # Creates worktree, cd's into it
claude                       # Start Claude Code
```

The `-o` flag can be placed anywhere:
```bash
wt -o create feature-auth    # Same as above
wt create -o feature-auth    # Also works
```

### Run multiple Claude sessions in parallel

Terminal 1:
```bash
cd ~/projects/my-app
wt create feature-auth -o
claude
```

Terminal 2:
```bash
cd ~/projects/my-app
wt create fix-bug-123 -o
claude
```

Both instances work independently with their own branches.

### Use an existing branch

```bash
wt create my-worktree existing-branch
```

### Nested branch names

```bash
wt create feature/auth/oauth -o
# Creates .worktrees/feature/auth/oauth/
```

### Remove with glob patterns

```bash
wt remove test1              # Remove exact match
wt remove 'test*'            # Remove all starting with "test"
wt remove 'feature/*'        # Remove all under feature/
```

### Configure base branch

By default, new branches are created from `origin/main`. You can configure this per-repo or globally:

```bash
# Set base branch for current repo
wt config base origin/develop

# Set global default (used when no repo config exists)
wt config base --global origin/main

# View current config
wt config

# List all configuration
wt config --list

# Unset repo config
wt config base --unset

# Unset global default
wt config base --global --unset
```

Configuration is stored in `~/.config/wt/config` (follows XDG spec).

**Resolution order:**
1. Repo-specific config
2. Global default
3. Hardcoded fallback (`origin/main`)

#### Config file format

The config file uses simple `key=value` pairs, one per line. You can edit it manually:

```bash
# View config file
cat ~/.config/wt/config

# Edit manually
$EDITOR ~/.config/wt/config
```

**Format reference:**

```ini
# Global default base branch
_default=origin/main

# Per-repo base branch (key is the absolute repo path)
/Users/you/projects/my-app=origin/develop
/Users/you/projects/api=origin/main

# Per-repo on-create hooks (key is repo path + ":on_create" suffix)
/Users/you/projects/my-app:on_create=pnpm install
/Users/you/projects/api:on_create=make deps
```

**Key patterns:**
| Key | Description |
|-----|-------------|
| `_default` | Global default base branch |
| `/path/to/repo` | Repo-specific base branch |
| `/path/to/repo:on_create` | Repo-specific on-create hook |

### Configure on-create hooks

Run commands automatically when creating worktrees. Useful for installing dependencies:

```bash
# Set on-create hook for current repo
wt config on-create 'pnpm install'

# View current hook
wt config on-create

# Create without running hook
wt create feature-branch --no-hooks

# Unset hook
wt config on-create --unset
```

Hooks run in the new worktree directory after creation. If a hook fails, a warning is displayed but the worktree remains usable.

**Examples:**
```bash
wt config on-create 'npm install'           # Node.js project
wt config on-create 'uv sync'               # Python UV project
wt config on-create 'make install'          # Makefile-based project
wt config on-create 'bundle install'        # Ruby project
```

## How it works

Worktrees are stored in `.worktrees/` inside your repo:

```
my-repo/
├── .worktrees/           # Auto-added to .git/info/exclude
│   ├── feature-a/
│   ├── feature-b/
│   └── feature/
│       └── auth/
│           └── oauth/
├── src/
└── ...
```

Each worktree is a full checkout of your repo on its own branch. Changes in one worktree don't affect others until you merge.

## Shell Integration

### Tab Completion

Both bash and zsh get tab completion:

```bash
wt <TAB>           # Shows: create list open remove cleanup config update version
wt open <TAB>      # Shows available worktrees
wt remove <TAB>    # Shows available worktrees
wt config <TAB>    # Shows: base on-create --list
```

### How the -o flag works

The `wt` shell function wraps the underlying `_wt` script. When you use `open` or the `-o` flag, the script outputs a `cd` command that the shell function `eval`s:

```bash
# What happens internally:
_wt open my-feature  # outputs: cd "/path/to/.worktrees/my-feature"
eval "cd ..."        # shell function evals it
```

This is why `wt open` can change your current directory.

### Why `which wt` doesn't work

Since `wt` is a shell function (required for `cd` functionality), `which wt` shows the function definition instead of a path. Use this instead:

```bash
wt which    # Shows path to the underlying _wt script
```

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

## License

MIT
