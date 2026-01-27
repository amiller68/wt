#!/bin/bash

# Init/Setup command implementation for wt
# Initializes wt.toml, docs/, issues/, .claude/, and CLAUDE.md

# Handle init/setup command
handle_setup() {
    local force=false
    local audit=false

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            --audit)
                audit=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                echo "Usage: wt init [--force] [--audit]" >&2
                exit 1
                ;;
        esac
    done

    # Check for jq
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq is required for wt init. Install it with your package manager.${NC}" >&2
        exit 1
    fi

    # Check if we're in a git repo; offer to create one if not
    if ! git rev-parse --show-toplevel &>/dev/null; then
        echo -e "${YELLOW}No git repository found in current directory.${NC}" >&2
        read -p "Run 'git init'? [y/N] " -r reply </dev/tty
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            git init
            echo "" >&2
        else
            echo -e "${RED}Aborted. Run 'git init' first.${NC}" >&2
            exit 1
        fi
    fi

    # Now detect repo (sets REPO_DIR, WORKTREES_BASE_DIR)
    detect_repo

    # Check if already initialized (wt.toml exists)
    if [ -f "$REPO_DIR/wt.toml" ] && [ "$force" != true ]; then
        echo -e "${RED}Error: Already initialized. Use --force to reinitialize.${NC}" >&2
        exit 1
    fi

    echo -e "${BLUE}Initializing wt for this repository...${NC}" >&2

    # 1. Create wt.toml
    init_wt_toml "$force"

    # 2. Copy docs from templates
    init_docs_dir "$force"

    # 3. Create issues directory
    mkdir -p "$REPO_DIR/issues"
    echo -e "${GREEN}Created issues/${NC}" >&2

    # 4. Set up Claude Code configuration
    local claude_dir="$REPO_DIR/.claude"
    local settings_file="$claude_dir/settings.json"
    local commands_dir="$claude_dir/commands"

    mkdir -p "$claude_dir"
    mkdir -p "$commands_dir"

    # Initialize or update settings.json
    setup_settings_json "$settings_file" "$force"

    # Copy command files
    setup_commands "$commands_dir" "$force"

    # 5. Copy CLAUDE.md template
    init_claude_md "$force"

    echo ""
    echo -e "${GREEN}Initialization complete!${NC}" >&2
    echo -e "${BLUE}Created:${NC}" >&2
    echo -e "  wt.toml                  - Spawn configuration" >&2
    echo -e "  docs/                    - Agent and project documentation" >&2
    echo -e "  issues/                  - File-based issue tracking" >&2
    echo -e "  .claude/                 - Claude Code settings and commands" >&2
    echo -e "  CLAUDE.md                - Project guide for Claude" >&2
    if [ "$audit" = true ]; then
        run_audit
    else
        echo ""
        echo -e "${YELLOW}Next steps:${NC}" >&2
        echo -e "  1. Edit docs/index.md with project-specific worker instructions" >&2
        echo -e "  2. Run: wt spawn <task> --context \"...\" --auto" >&2
    fi
}

# Alias for backwards compatibility
handle_init() {
    handle_setup "$@"
}

# Run Claude Code audit to populate docs/ with project-specific content
run_audit() {
    if ! command -v claude &>/dev/null; then
        echo -e "${RED}Error: claude CLI is required for --audit. Install it first.${NC}" >&2
        exit 1
    fi

    echo "" >&2
    echo -e "${BLUE}Running audit: launching Claude to explore and document this codebase...${NC}" >&2

    local audit_prompt
    audit_prompt='Explore this codebase and populate the project documentation.

1. Read CLAUDE.md and docs/ to understand the current doc structure
2. Explore the codebase: key files, directory structure, languages, frameworks, build system, test setup
3. Update docs/index.md with project-specific instructions for AI coding agents:
   - Project overview and purpose
   - Key files and directories
   - How to build, test, and run
   - Code conventions and patterns to follow
   - Common gotchas or important context
4. Do NOT modify docs/issue-tracking.md (this is a generic guide)
5. Commit your changes with a clear message'

    (cd "$REPO_DIR" && claude -p "$audit_prompt")
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

# Copy docs template files from wt install dir to repo docs/
init_docs_dir() {
    local force="$1"
    local docs_dir="$REPO_DIR/docs"
    local wt_docs_dir="$INSTALL_DIR/templates/docs"

    mkdir -p "$docs_dir"

    if [ ! -d "$wt_docs_dir" ]; then
        echo -e "${YELLOW}No templates/docs directory found in wt installation${NC}" >&2
        return 0
    fi

    # Copy each template file
    for src_file in "$wt_docs_dir"/*.md; do
        [ -f "$src_file" ] || continue

        local basename
        basename=$(basename "$src_file")
        local target="$docs_dir/$basename"

        if [ -f "$target" ] && [ "$force" != true ]; then
            echo -e "${YELLOW}docs/$basename already exists (skipping)${NC}" >&2
            continue
        fi

        cp "$src_file" "$target"
        echo -e "${GREEN}Created docs/$basename${NC}" >&2
    done

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
}

# Copy CLAUDE.md template to repo root
init_claude_md() {
    local force="$1"
    local claude_md="$REPO_DIR/CLAUDE.md"
    local template="$INSTALL_DIR/templates/CLAUDE.md"

    if [ -f "$claude_md" ] && [ "$force" != true ]; then
        echo -e "${YELLOW}CLAUDE.md already exists (skipping)${NC}" >&2
        return 0
    fi

    if [ -f "$template" ]; then
        cp "$template" "$claude_md"
        echo -e "${GREEN}Created CLAUDE.md${NC}" >&2
    else
        echo -e "${YELLOW}No CLAUDE.md template found in wt installation${NC}" >&2
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

    local wt_commands_dir="$INSTALL_DIR/templates/commands"

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
