# Development Guide

Guide for AI agents and developers working on this Git worktree manager.

## Project Overview

`wt` is a CLI tool for managing git worktrees, designed for parallel Claude Code sessions.

## Documentation

- `docs/index.md` — Agent instructions and key files reference
- `docs/issue-tracking.md` — File-based issue tracking convention

## Versioning

- **Location:** `manifest.toml`
- **Format:** Semantic versioning (MAJOR.MINOR.PATCH)
- **Rules:**
  - MAJOR: Breaking changes (removed commands, changed behavior)
  - MINOR: New features, commands, flags (backward compatible)
  - PATCH: Bug fixes, docs, internal refactoring

## Testing

- **Run all:** `./test.sh`
- **Structure:** `tests/test_*.sh` modules, `assert_*` helpers in test.sh
- **Adding tests:** Create new test module or add to existing one

## Documentation Updates

Update `README.md` when:
- New commands/flags added
- Behavior changed
- New configuration options

## Issues

Track work items in `issues/`. See `docs/issue-tracking.md` for the convention.
