# Project Guide

`wt` is a bash CLI for managing git worktrees, designed for parallel Claude Code sessions.

## Quick Reference

```bash
source ./dev.sh     # Use local wt for development
./test.sh           # Run all tests (required before committing)
```

## Documentation

Project documentation lives in `docs/`:
- `docs/index.md` — Agent instructions for spawned workers (project overview, architecture, conventions)
- `docs/issue-tracking.md` — File-based issue tracking convention

## Issues

Track work items in `issues/`. See `docs/issue-tracking.md` for the convention.

## Versioning

- **Location:** `manifest.toml`
- **Format:** Semantic versioning (MAJOR.MINOR.PATCH)
- MAJOR: Breaking changes (removed commands, changed behavior)
- MINOR: New features, commands, flags (backward compatible)
- PATCH: Bug fixes, docs, internal refactoring

## Key Conventions

- Pure bash, no build step. All code in `_wt.sh` and `lib/*.sh`
- Functions use `snake_case`, command handlers use `handle_<command>()`
- stdout is for eval-able output only; errors and messages go to stderr
- Quote all variables, use `[[ ... ]]` for conditionals
- Tests go in `tests/test_<feature>.sh`
- Run `./test.sh` before committing
