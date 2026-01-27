Discover and manage work items for the project.

Run this command to explore what needs to be done before spawning workers with `/spawn`.

## Actions

1. **List issues**: Scan `issues/` and show all epics and tickets with their status
2. **Show issue**: Read a specific issue file and display its contents
3. **Create epic**: Create a new epic file from the template in `docs/issue-tracking.md`
4. **Create ticket**: Create a new ticket file linked to an epic
5. **Update status**: Change a ticket's status (Planned -> In Progress -> Complete)

## Discovery

When listing issues, scan `issues/*.md` and extract:
- Filename
- Title (first `# ` heading)
- Status (from `**Status:**` field)
- Epic (from `**Epic:**` field, for tickets)

Group tickets under their parent epic. Show status with indicators:
- Planned: `[ ]`
- In Progress: `[~]`
- Complete: `[x]`
- Blocked: `[!]`

Identify which tickets are ready to work on (status: Planned, no blockers).

## Convention

See `docs/issue-tracking.md` for the full issue tracking convention.

## External Trackers

This uses file-based issue tracking by default. For external trackers like Linear, use the Linear MCP tools instead and skip the file scanning.
