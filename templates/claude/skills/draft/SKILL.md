---
name: draft
description: Draft PR descriptions and commit messages. Use when preparing work for review, creating pull requests, summarizing changes, or writing commit messages.
---

# Drafting

## PR Description

1. Run `git diff main...HEAD` (or appropriate base branch)
2. Summarize what changed and why
3. List key changes by area
4. Note any breaking changes or migration steps
5. Reference related issues

## Format

```markdown
## Summary
Brief description of what this PR does.

## Changes
- Component A: description
- Component B: description

## Testing
How to test these changes.

## Related Issues
Fixes #NNN
```

## Commit Messages

Use conventional commits:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation
- `refactor:` code change that neither fixes nor adds
- `test:` adding tests
- `chore:` maintenance

Keep summary under 50 chars, add detail in body if needed.
