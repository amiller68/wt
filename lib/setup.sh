#!/bin/bash

# Init/Setup command implementation for wt
# Initializes wt.toml, agents directory, and Claude Code settings

# Handle init/setup command
handle_setup() {
    local force=false

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                echo "Usage: wt init [--force]" >&2
                exit 1
                ;;
        esac
    done

    # Check for jq
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq is required for wt init. Install it with your package manager.${NC}" >&2
        exit 1
    fi

    echo -e "${BLUE}Initializing wt for this repository...${NC}" >&2

    # 1. Create wt.toml if it doesn't exist
    init_wt_toml "$force"

    # 2. Create agents directory with INDEX.md
    init_agents_dir "$force"

    # 3. Set up Claude Code configuration
    local claude_dir="$REPO_DIR/.claude"
    local settings_file="$claude_dir/settings.json"
    local commands_dir="$claude_dir/commands"

    mkdir -p "$claude_dir"
    mkdir -p "$commands_dir"

    # Initialize or update settings.json
    setup_settings_json "$settings_file" "$force"

    # Copy command files
    setup_commands "$commands_dir" "$force"

    echo ""
    echo -e "${GREEN}Initialization complete!${NC}" >&2
    echo -e "${BLUE}Created:${NC}" >&2
    echo -e "  wt.toml                  - Spawn configuration" >&2
    echo -e "  agents/INDEX.md          - Instructions for spawned workers" >&2
    echo -e "  agents/ORCHESTRATION.md  - Guide for parent orchestration" >&2
    echo -e "  .claude/                 - Claude Code settings" >&2
    echo -e "  CLAUDE.md                - References agents/" >&2
    echo ""
    echo -e "${YELLOW}Next steps:${NC}" >&2
    echo -e "  1. Edit agents/INDEX.md with project-specific worker instructions" >&2
    echo -e "  2. Review agents/ORCHESTRATION.md for orchestration guide" >&2
    echo -e "  3. Run: wt spawn <task> --context \"...\" --auto" >&2
}

# Alias for backwards compatibility
handle_init() {
    handle_setup "$@"
}

# Create wt.toml with sensible defaults
init_wt_toml() {
    local force="$1"
    local toml_file="$REPO_DIR/wt.toml"

    if [ -f "$toml_file" ] && [ "$force" != true ]; then
        echo -e "${YELLOW}wt.toml already exists (skipping)${NC}" >&2
        return 0
    fi

    cat > "$toml_file" << 'EOF'
# wt configuration
# See: https://github.com/amiller68/worktree

[spawn]
# Always use auto mode (--auto flag)
auto = true

[agents]
# Directory containing agent context files
dir = "./agents"

[setup]
# Bash commands to allow without prompting
allow = [
    "git status",
    "git diff",
    "git add",
    "git commit",
    "git push",
    "git log",
    "git branch"
]

# Bash commands to deny
deny = [
    "rm -rf *",
    "sudo *"
]
EOF

    echo -e "${GREEN}Created wt.toml${NC}" >&2
}

# Create agents directory with INDEX.md and ORCHESTRATION.md
init_agents_dir() {
    local force="$1"
    local agents_dir="$REPO_DIR/agents"
    local index_file="$agents_dir/INDEX.md"
    local orch_file="$agents_dir/ORCHESTRATION.md"

    mkdir -p "$agents_dir"

    # Create INDEX.md (instructions for spawned workers)
    if [ -f "$index_file" ] && [ "$force" != true ]; then
        echo -e "${YELLOW}agents/INDEX.md already exists (skipping)${NC}" >&2
    else
        cat > "$index_file" << 'EOF'
# Agent Instructions

You are an autonomous coding agent working on a focused task.

## Workflow

1. **Understand** - Read the task description carefully
2. **Explore** - Search the codebase to understand context and patterns
3. **Plan** - Break down the work into small steps
4. **Implement** - Make changes following existing conventions
5. **Test** - Run tests to verify your changes work
6. **Commit** - Commit with a clear, descriptive message

## Guidelines

- Follow existing code patterns and conventions
- Make atomic commits (one logical change per commit)
- Add tests for new functionality
- Update documentation if behavior changes
- If blocked, commit what you have and note the blocker

## When Complete

Your work will be reviewed and merged by the parent session.
Ensure all tests pass before finishing.
EOF
        echo -e "${GREEN}Created agents/INDEX.md${NC}" >&2
    fi

    # Create ORCHESTRATION.md (instructions for parent orchestrator)
    if [ -f "$orch_file" ] && [ "$force" != true ]; then
        echo -e "${YELLOW}agents/ORCHESTRATION.md already exists (skipping)${NC}" >&2
    else
        cat > "$orch_file" << 'EOF'
# Multi-Agent Orchestration

Use `wt` to spawn parallel Claude Code workers for large tasks.

## Commands

```bash
wt spawn <name> --context "..." --auto  # Spawn autonomous worker
wt ps                                    # Check worker status
wt attach [name]                         # Watch workers in tmux
wt review <name>                         # Review worker's changes
wt merge <name>                          # Merge into current branch
wt kill <name>                           # Stop a worker
wt remove <name>                         # Delete worktree
```

## Workflow

1. **Create integration branch**: `wt -o create epic-<id>`
2. **Decompose** the work into independent, parallelizable tasks
3. **Spawn workers** with specific context for each task
4. **Monitor**: `wt ps` to check status
5. **Review & merge** as workers complete
6. **Clean up**: `wt remove <id>`

## Writing Spawn Context

Each spawn should have focused, specific context:

```bash
wt spawn TASK-123 --context "Implement user authentication.

Files to modify:
- src/auth/login.ts
- src/middleware/auth.ts

Requirements:
- Add JWT token generation
- Add auth middleware
- Add login endpoint

Acceptance criteria:
- All tests pass
- Login flow works end-to-end" --auto
```

## Tips

- Keep tasks independent when possible
- Include specific file paths if known
- Set clear acceptance criteria
- Spawn 2-4 workers at a time, merge as they complete
- Use `wt attach` to monitor progress
EOF
        echo -e "${GREEN}Created agents/ORCHESTRATION.md${NC}" >&2
    fi

    # Update .gitignore
    local gitignore="$REPO_DIR/.gitignore"
    if [ -f "$gitignore" ]; then
        if ! grep -q "^# wt spawn files$" "$gitignore" 2>/dev/null; then
            cat >> "$gitignore" << 'EOF'

# wt spawn files
.claude-task
.claude-spawn-prompt
EOF
            echo -e "${GREEN}Updated .gitignore${NC}" >&2
        fi
    fi

    # Update CLAUDE.md to reference agents/
    update_claude_md
}

# Add reference to agents/ in CLAUDE.md
update_claude_md() {
    local claude_md="$REPO_DIR/CLAUDE.md"
    local marker="# Agent Context"

    # Check if already has reference
    if [ -f "$claude_md" ] && grep -q "$marker" "$claude_md" 2>/dev/null; then
        return 0
    fi

    local agents_ref="
$marker

For multi-agent orchestration, see \`agents/ORCHESTRATION.md\`.
Spawned workers receive instructions from \`agents/INDEX.md\`.
"

    if [ -f "$claude_md" ]; then
        # Append to existing CLAUDE.md
        echo "$agents_ref" >> "$claude_md"
        echo -e "${GREEN}Updated CLAUDE.md with agents reference${NC}" >&2
    else
        # Create minimal CLAUDE.md
        cat > "$claude_md" << EOF
# Project Guide
$agents_ref
EOF
        echo -e "${GREEN}Created CLAUDE.md${NC}" >&2
    fi
}

# Setup settings.json with permissions from wt.toml
setup_settings_json() {
    local settings_file="$1"
    local force="$2"

    local existing_settings='{}'
    if [ -f "$settings_file" ]; then
        existing_settings=$(cat "$settings_file")
    fi

    # Start with existing or default structure
    local new_settings
    new_settings=$(echo "$existing_settings" | jq '{
        permissions: (.permissions // {allow: [], deny: []})
    }')

    # Read permissions from wt.toml if available
    if has_wt_toml "$REPO_DIR"; then
        echo -e "${BLUE}Reading permissions from wt.toml...${NC}" >&2

        # Get allow permissions
        local allow_perms
        allow_perms=$(get_wt_config_array "setup.allow" "$REPO_DIR") || true

        if [ -n "$allow_perms" ]; then
            # Build JSON array of allow permissions
            local allow_json='[]'
            while IFS= read -r perm; do
                [ -z "$perm" ] && continue
                allow_json=$(echo "$allow_json" | jq --arg p "Bash($perm)" '. + [$p]')
            done <<< "$allow_perms"

            # Merge with existing allow permissions
            new_settings=$(echo "$new_settings" | jq --argjson new "$allow_json" '
                .permissions.allow = ((.permissions.allow // []) + $new | unique)
            ')
        fi

        # Get deny permissions
        local deny_perms
        deny_perms=$(get_wt_config_array "setup.deny" "$REPO_DIR") || true

        if [ -n "$deny_perms" ]; then
            # Build JSON array of deny permissions
            local deny_json='[]'
            while IFS= read -r perm; do
                [ -z "$perm" ] && continue
                deny_json=$(echo "$deny_json" | jq --arg p "Bash($perm)" '. + [$p]')
            done <<< "$deny_perms"

            # Merge with existing deny permissions
            new_settings=$(echo "$new_settings" | jq --argjson new "$deny_json" '
                .permissions.deny = ((.permissions.deny // []) + $new | unique)
            ')
        fi
    fi

    # Write settings file
    echo "$new_settings" | jq '.' > "$settings_file"
    echo -e "${GREEN}Updated settings.json${NC}" >&2
}

# Copy command files from wt install dir to .claude/commands
setup_commands() {
    local commands_dir="$1"
    local force="$2"

    local wt_commands_dir="$INSTALL_DIR/commands"

    if [ ! -d "$wt_commands_dir" ]; then
        echo -e "${YELLOW}No commands directory found in wt installation${NC}" >&2
        return 0
    fi

    local copied=0
    for cmd_file in "$wt_commands_dir"/*.md; do
        [ -f "$cmd_file" ] || continue

        local basename
        basename=$(basename "$cmd_file")
        local target="$commands_dir/$basename"

        if [ -f "$target" ] && [ "$force" != true ]; then
            echo -e "${YELLOW}Skipping $basename (already exists)${NC}" >&2
            continue
        fi

        cp "$cmd_file" "$target"
        echo -e "${GREEN}Installed command: $basename${NC}" >&2
        ((copied++))
    done

    if [ $copied -eq 0 ]; then
        echo -e "${YELLOW}No new commands installed${NC}" >&2
    else
        echo -e "${GREEN}Installed $copied command(s)${NC}" >&2
    fi
}
