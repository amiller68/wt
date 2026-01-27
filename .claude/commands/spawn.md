Spawn parallel Claude Code workers to execute a set of tasks.

## Workflow

1. Run `/issues` to discover and understand the work to be done
2. Decompose into independent, parallelizable tasks
3. For each task, spawn a worker:
   ```bash
   wt spawn <task-name> --context "<detailed context>" --auto
   ```
4. Monitor with `wt ps`
5. As workers complete, review and merge:
   ```bash
   wt review <task-name>
   wt merge <task-name>
   ```

## Context Template

Each spawn context should include:
- One-line summary of the task
- Files to modify (if known)
- Specific requirements
- Acceptance criteria

## Rules

- Keep tasks independent when possible
- Include enough context for the worker to be autonomous
- Spawn 2-4 workers at a time
- Review before merging
- Use `wt kill <name>` if a worker is stuck
