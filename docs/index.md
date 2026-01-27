# Agent Instructions

You are working on `wt` — a bash CLI for managing git worktrees, designed for parallel Claude Code sessions. Pure bash, no build step.

## Key Files

```
_wt.sh              # Main entry point and command dispatcher
lib/
├── config.sh       # Config file handling (~/.config/wt/config)
├── setup.sh        # wt init — repo initialization, template copying
├── spawn.sh        # Spawn state tracking (JSON in ~/.config/wt/spawned/)
└── tmux.sh         # tmux session/window management for spawned workers
shell/
├── wt.bash         # Bash shell integration + completions
└── wt.zsh          # Zsh shell integration + completions
templates/          # Files copied by wt init (docs, commands, CLAUDE.md)
test.sh             # Test runner
tests/              # Test modules (test_basic.sh, test_config.sh, etc.)
manifest.toml       # Version (semver)
```

## Development

```bash
source ./dev.sh     # Use local wt instead of installed version
./test.sh           # Run all tests (isolated temp repo, XDG isolated)
```

## Conventions

- Functions: `snake_case`, handlers: `handle_<command>()`
- Errors to stderr, color-coded (`RED`, `GREEN`, `BLUE`, `YELLOW`)
- stdout is reserved for eval-able output (e.g. `cd` commands)
- Quote all variables, use `[[ ... ]]` for conditionals
- Add tests in `tests/test_<feature>.sh` for new functionality

## Workflow

1. Read the task description
2. Explore the codebase for context and patterns
3. Implement following existing conventions
4. Run `./test.sh`
5. Commit with a clear message
