---
name: issues
description: Work with project issues tracked as markdown files. Use when finding issues to work on, creating new issues, updating issue status, or understanding what needs to be done.
---

# Issues

Issues are tracked in `issues/` as markdown files with YAML frontmatter.

## Finding Issues

```bash
ls issues/
grep -l "status: ready" issues/*.md  # Find ready issues
```

## Issue Format

```markdown
---
id: NNN
title: Short title
status: draft|ready|in_progress|review|done
depends_on: []
---

## Description

What needs to be done.

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
```

## Status Values

- `draft` - Not ready to work on
- `ready` - Ready to be picked up
- `in_progress` - Someone is working on it
- `review` - Work done, needs review
- `done` - Complete

## Creating Issues

Copy `issues/_template.md`, assign next ID, fill in details.

## Updating Status

When starting work: change status to `in_progress`
When done: change status to `review` or `done`
