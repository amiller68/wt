#!/bin/bash

# Init/Setup command implementation for wt
# Initializes wt.toml, docs/, issues/, .claude/, and CLAUDE.md

# Handle init/setup command
handle_setup() {
    local force=false
    local audit=false
    local backup=false

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
            --backup)
                backup=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                echo "Usage: wt init [--force] [--backup] [--audit]" >&2
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

    # Now detect repo (sets REPO_DIR, WORKTREES_BASE_DIR, TOPLEVEL_DIR)
    detect_repo

    # Init targets the current toplevel (worktree-aware), not the base repo
    REPO_DIR="$TOPLEVEL_DIR"

    # Check if already initialized (wt.toml exists)
    if [ -f "$REPO_DIR/wt.toml" ] && [ "$force" != true ]; then
        echo -e "${RED}Error: Already initialized. Use --force to reinitialize.${NC}" >&2
        exit 1
    fi

    # Backup existing files before overwriting
    if [ "$backup" = true ]; then
        backup_existing_files
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
    local commands_dir="$claude_dir/commands"

    mkdir -p "$commands_dir"

    # Create settings.json with sensible defaults
    setup_settings_json "$claude_dir/settings.json" "$force"

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
        run_audit "$backup"
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

# Backup files that would be overwritten by init
backup_existing_files() {
    local backup_dir="$REPO_DIR/.wt-backup"
    local backed_up=0

    # Files and directories that init overwrites
    local files_to_check=(
        "CLAUDE.md"
        "wt.toml"
        ".claude/settings.json"
    )
    local dirs_to_check=(
        ".claude/commands"
        "docs"
    )

    for f in "${files_to_check[@]}"; do
        if [ -f "$REPO_DIR/$f" ]; then
            mkdir -p "$backup_dir/$(dirname "$f")"
            cp "$REPO_DIR/$f" "$backup_dir/$f"
            ((backed_up++))
        fi
    done

    for d in "${dirs_to_check[@]}"; do
        if [ -d "$REPO_DIR/$d" ]; then
            mkdir -p "$backup_dir/$d"
            cp -r "$REPO_DIR/$d"/. "$backup_dir/$d"/
            ((backed_up++))
        fi
    done

    if [ $backed_up -gt 0 ]; then
        echo -e "${GREEN}Backed up $backed_up item(s) to .wt-backup/${NC}" >&2
    else
        echo -e "${YELLOW}No existing files to back up${NC}" >&2
    fi
}

# Run Claude Code audit to populate docs/ with project-specific content
run_audit() {
    local has_backup="$1"

    if ! command -v claude &>/dev/null; then
        echo -e "${RED}Error: claude CLI is required for --audit. Install it first.${NC}" >&2
        exit 1
    fi

    echo "" >&2
    echo -e "${BLUE}Running audit: launching Claude to explore and document this codebase...${NC}" >&2

    local audit_prompt
    if [ "$has_backup" = true ] && [ -d "$REPO_DIR/.wt-backup" ]; then
        audit_prompt='Explore this codebase and populate the project documentation.

A backup of previous configuration exists in .wt-backup/. Fresh templates have
been applied. Your job is to produce the best possible result by combining the
new template structure with any valuable customizations from the backup.

1. Read CLAUDE.md and docs/ to understand the new template structure
2. Read .wt-backup/ to see what the user had before (customizations, project-specific content)
3. Explore the codebase: key files, directory structure, languages, frameworks, build system, test setup
4. Update docs/index.md with project-specific instructions for AI coding agents:
   - Project overview and purpose
   - Key files and directories
   - How to build, test, and run
   - Code conventions and patterns to follow
   - Common gotchas or important context
   Incorporate any useful project-specific content from .wt-backup/docs/ if present.
5. Update CLAUDE.md: merge the template structure with any project-specific sections
   from .wt-backup/CLAUDE.md (versioning rules, testing instructions, etc.)
6. Review .wt-backup/.claude/commands/ for any custom commands and copy them to
   .claude/commands/ if they are not already present from the template
7. Do NOT modify docs/issue-tracking.md (this is a generic guide)
8. Commit your changes with a clear message'
    else
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
    fi

    (cd "$REPO_DIR" && claude -p --dangerously-skip-permissions "$audit_prompt")
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

# Create .claude/settings.json with sensible defaults
setup_settings_json() {
    local settings_file="$1"
    local force="$2"

    if [ -f "$settings_file" ] && [ "$force" != true ]; then
        echo -e "${YELLOW}settings.json already exists (skipping)${NC}" >&2
        return 0
    fi

    cat > "$settings_file" << 'SETTINGS_EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git branch:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git checkout:*)",
      "Bash(git stash:*)",
      "Bash(git pull:*)",
      "Bash(git push:*)",
      "Bash(git fetch:*)",
      "Bash(git remote:*)",
      "Bash(git rev-parse:*)",
      "Bash(git worktree:*)",
      "Bash(git reset:*)",
      "Bash(git restore:*)",
      "Bash(gh pr view:*)",
      "Bash(gh pr list:*)",
      "Bash(gh pr diff:*)",
      "Bash(gh pr create:*)",
      "Bash(gh pr checks:*)",
      "Bash(gh issue list:*)",
      "Bash(gh issue view:*)",
      "Bash(gh repo view:*)",
      "Bash(gh status)",
      "Bash(cat:*)",
      "Bash(find:*)",
      "Bash(ls:*)",
      "Bash(pwd)",
      "Bash(echo:*)",
      "Bash(which:*)",
      "Bash(head:*)",
      "Bash(tail:*)",
      "Bash(grep:*)",
      "Bash(rg:*)",
      "Bash(mkdir:*)",
      "Bash(touch:*)",
      "Bash(cp:*)",
      "Bash(mv:*)",
      "Bash(rm -f:*)",
      "Bash(chmod:*)",
      "Bash(wc:*)",
      "Bash(sort:*)",
      "Bash(uniq:*)",
      "Bash(tree:*)",
      "Bash(diff:*)",
      "Bash(stat:*)",
      "Bash(file:*)",
      "Bash(sed:*)",
      "Bash(awk:*)",
      "Bash(xargs:*)",
      "Bash(date:*)",
      "Bash(env:*)",
      "Bash(basename:*)",
      "Bash(dirname:*)",
      "Bash(realpath:*)",
      "Bash(tmux:*)",
      "Bash(jq:*)",
      "Bash(curl:*)",
      "Bash(ps:*)",
      "Read",
      "Write",
      "Edit",
      "WebSearch",
      "WebFetch"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(rm -r:*)",
      "Bash(sudo:*)",
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Read(.env)",
      "Read(.env.*)",
      "Read(./.env*)",
      "Read(**/.env*)",
      "Read(**/.aws/**)",
      "Read(**/.ssh/**)",
      "Read(*.pem)",
      "Read(*.key)",
      "Write(.env)",
      "Write(.env.*)",
      "Write(./.env*)",
      "Write(*.pem)",
      "Write(*.key)",
      "Edit(.env)",
      "Edit(.env.*)",
      "Edit(./.env*)"
    ]
  }
}
SETTINGS_EOF

    echo -e "${GREEN}Created settings.json${NC}" >&2
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
