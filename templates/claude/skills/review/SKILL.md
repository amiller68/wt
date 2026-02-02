---
name: review
description: Review code for quality, security, and conventions. Use when reviewing pull requests, checking code changes, analyzing diffs, or doing code review.
---

# Code Review

## Checklist

1. **Correctness** - Does it do what it's supposed to?
2. **Tests** - Are changes tested? Do tests pass?
3. **Security** - Any vulnerabilities? Input validation?
4. **Performance** - Any obvious bottlenecks?
5. **Readability** - Clear names? Reasonable complexity?
6. **Conventions** - Follows project patterns?

## Process

1. Read the PR description / task
2. Review the diff: `git diff main...HEAD`
3. Check test coverage
4. Run tests locally if needed
5. Note issues by severity:
   - Must fix - blocks merge
   - Should fix - important but not blocking
   - Suggestion - nice to have

## Feedback Format

Be specific and constructive:
- Bad: "This is wrong"
- Good: "This could cause X because Y. Consider Z instead."
