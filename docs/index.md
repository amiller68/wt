# Agent Instructions

You are an autonomous coding agent working on a focused task in the `wt` project.

## Project Overview

`wt` is a git worktree manager for running parallel Claude Code sessions. It is a pure Bash tool (no compiled language, no package manager) that wraps `git worktree` with convenience commands and multi-agent orchestration via tmux.

- **Repository:** `github.com/amiller68/worktree`
- **Language:** Bash (100%)
- **Version:** defined in `manifest.toml`
- **License:** MIT

## Directory Structure

```
_wt.sh              # Main script — all core command handlers live here
manifest.toml       # Package metadata (name, version, description)
wt.toml             # Per-repo spawn configuration
lib/
  config.sh          # wt.toml parser (simple TOML reader)
  setup.sh           # `wt init` command — scaffolding for new repos
  spawn.sh           # Spawn state management (JSON via jq)
  tmux.sh            # tmux session/window helpers for `wt spawn`
shell/
  wt.bash            # Bash shell integration (function + completion)
  wt.zsh             # Zsh shell integration (function + completion)
templates/
  CLAUDE.md           # Template copied by `wt init`
  commands/           # Slash-command templates (check, draft, issues, review, spawn)
  docs/               # Doc templates (index.md, issue-tracking.md)
docs/
  index.md            # This file — agent instructions for spawned workers
  issue-tracking.md   # File-based issue tracking convention
  usage/
    orchestration.md  # Orchestration guide for multi-agent workflows
tests/
  test_basic.sh       # Core worktree CRUD tests
  test_nested.sh      # Nested branch path tests
  test_config.sh      # Config command tests
  test_exit.sh        # Exit/cleanup tests
  test_hooks.sh       # On-create hook tests
  test_open_all.sh    # Multi-tab open tests
  test_spawn.sh       # Spawn command tests
install.sh           # Installer (curl | bash)
dev.sh               # Local dev setup (source ./dev.sh)
test.sh              # Test runner entry point
.claude/
  settings.json      # Claude Code permissions (allow/deny lists)
  commands/           # Slash commands available in Claude Code sessions
.github/
  workflows/
    test.yml          # CI — runs test.sh on Ubuntu + macOS
```

## How to Build, Test, and Run

There is no build step. `wt` is a Bash script.

### Local development

```bash
source ./dev.sh     # Symlinks _wt, adds to PATH, sources shell integration
wt version          # Verify local version is active
```

### Running tests

```bash
./test.sh
```

Tests create a temporary git repo, run all test modules in `tests/`, and clean up. The test runner uses `assert_eq`, `assert_dir_exists`, and `assert_dir_not_exists` helpers defined in `test.sh`. Each `tests/test_*.sh` file is sourced (not executed as a subprocess), so they share state with the runner.

### CI

GitHub Actions runs `./test.sh` on both `ubuntu-latest` and `macos-latest` on pushes/PRs to `main`.

## Code Conventions

- **Pure Bash.** No external languages. Dependencies are common Unix tools: `git`, `jq`, `tmux`, `sed`, `grep`.
- **`set -e`** is used in `_wt.sh`. Functions should handle errors explicitly where early-exit would be problematic.
- **Library sourcing.** `_wt.sh` sources `lib/*.sh` files at startup. Each lib file is a self-contained module.
- **Color output.** Use the color variables (`RED`, `GREEN`, `BLUE`, `YELLOW`, `BOLD`, `NC`) defined in `_wt.sh`. Print user-facing messages to stderr (`>&2`); only machine-readable output (like `cd` commands for `eval`) goes to stdout.
- **Shell integration.** The `wt` shell function (in `shell/wt.bash` / `shell/wt.zsh`) wraps `_wt` and `eval`s output for commands that need to change the working directory (`open`, `exit`, `create -o`).
- **Config storage.** User config lives at `~/.config/wt/config` (respects `XDG_CONFIG_HOME`). Per-repo config uses `wt.toml` with a simple TOML parser in `lib/config.sh`.
- **Spawn state.** Stored as JSON in `~/.config/wt/spawned/` (one file per repo, keyed by md5 hash of repo path).
- **tmux conventions.** All spawned workers share a single tmux session named `wt-spawned`, each in its own window named after the task.
- **Tests.** Test files are sourced by `test.sh`, not run as subprocesses. Use `assert_eq`, `assert_dir_exists`, `assert_dir_not_exists`. Tests share `$TEST_DIR` (temp git repo) and `$PASS`/`$FAIL` counters.
- **Templates.** Files in `templates/` are copied verbatim by `wt init`. If you change a template, the change only affects newly-initialized repos.

## Workflow

1. **Understand** - Read the task description carefully
2. **Explore** - Search the codebase to understand context and patterns
3. **Plan** - Break down the work into small steps
4. **Implement** - Make changes following existing conventions
5. **Test** - Run `./test.sh` to verify your changes work
6. **Commit** - Commit with a clear, descriptive message

## Common Gotchas

- **stdout vs stderr.** Commands like `open` and `exit` rely on stdout being a `cd` command that the shell function `eval`s. All human-readable output must go to stderr. If you write to stdout by accident, the shell function will try to `eval` it.
- **Worktree detection.** `_wt.sh` distinguishes between the base repo (`REPO_DIR`) and the current worktree toplevel (`TOPLEVEL_DIR`). `wt init` targets `TOPLEVEL_DIR` so it works inside worktrees.
- **No subprocesses in tests.** Test files are `source`d, not executed. Variables and functions leak between test files. The `PASS`/`FAIL` counters are shared globals.
- **Glob patterns in `wt remove`.** The remove command supports shell glob matching against worktree names. Quote glob patterns to prevent shell expansion.
- **macOS + Linux compat.** The test suite runs on both. Be careful with flags that differ between GNU and BSD coreutils (e.g., `md5sum` vs `md5`, `sed -i` differences).
- **`.gitignore` management.** Several commands append to `.gitignore` (spawn context files, prompt files). Check before appending to avoid duplicates.

## When Complete

Your work will be reviewed and merged by the parent session.
Ensure all tests pass before finishing.
