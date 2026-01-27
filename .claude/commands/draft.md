---
description: Draft a commit message for staged changes
allowed-tools:
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Read
---

Draft a commit message for the currently staged changes.

## Steps

1. Check that there are staged changes:
   ```
   git diff --cached --stat
   ```
   If nothing is staged, tell the user and stop.

2. Read the full staged diff:
   ```
   git diff --cached
   ```

3. Check recent commit history for the project's commit style:
   ```
   git log --oneline -10
   ```

4. Draft a commit message following the project's conventions:
   - Use conventional commit format if the project uses it (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
   - First line: concise summary under 72 characters
   - Blank line, then body with context on **why** the change was made
   - Reference issue numbers if apparent from branch name or diff

5. Present the draft to the user for approval or edits.

## Important

- Focus on the "why" not the "what" — the diff shows what changed
- Do NOT run `git commit` — only draft the message
- If the diff is large, group changes by theme in the body
