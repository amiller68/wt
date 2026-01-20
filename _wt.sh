#!/bin/bash

# Git Worktree Setup Script for Multiple Claude Code Instances
# This script helps create separate git worktrees for working with multiple
# instances of Claude Code on any git repository

set -e

# Install location (set by installer)
INSTALL_DIR="${WORKTREE_INSTALL_DIR:-$HOME/.local/share/worktree}"

# Source library files
LIB_DIR="$INSTALL_DIR/lib"
[ -f "$LIB_DIR/linear.sh" ] && source "$LIB_DIR/linear.sh"
[ -f "$LIB_DIR/tmux.sh" ] && source "$LIB_DIR/tmux.sh"
[ -f "$LIB_DIR/epic.sh" ] && source "$LIB_DIR/epic.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Detect current terminal emulator
detect_terminal() {
    case "$TERM_PROGRAM" in
        ghostty)        echo "ghostty" ;;
        iTerm.app)      echo "iterm2" ;;
        Apple_Terminal) echo "terminal.app" ;;
        WezTerm)        echo "wezterm" ;;
        Alacritty)      echo "alacritty" ;;
        *)
            if [ -n "$KITTY_WINDOW_ID" ]; then
                echo "kitty"
            elif [ -n "$WEZTERM_UNIX_SOCKET" ]; then
                echo "wezterm"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Open a new terminal tab at the specified directory
open_terminal_tab() {
    local dir="$1"
    local terminal=$(detect_terminal)

    case "$terminal" in
        iterm2)
            osascript -e "tell application \"iTerm2\"
                tell current window
                    create tab with default profile
                    tell current session
                        write text \"cd '$dir' && exec \$SHELL\"
                    end tell
                end tell
            end tell" >/dev/null 2>&1
            ;;
        terminal.app)
            osascript -e "tell application \"Terminal\"
                activate
                tell application \"System Events\" to keystroke \"t\" using {command down}
                delay 0.2
                do script \"cd '$dir'\" in front window
            end tell" >/dev/null 2>&1
            ;;
        ghostty)
            # Ghostty on macOS: open -a opens a new tab when Ghostty is already running
            open -a Ghostty "$dir"
            ;;
        kitty)
            kitten @ launch --type=tab --cwd="$dir" 2>/dev/null || {
                echo -e "${YELLOW}Warning: Kitty remote control not enabled. Add 'allow_remote_control yes' to kitty.conf${NC}" >&2
                return 1
            }
            ;;
        wezterm)
            wezterm cli spawn --cwd "$dir" 2>/dev/null || {
                echo -e "${YELLOW}Warning: WezTerm CLI spawn failed${NC}" >&2
                return 1
            }
            ;;
        alacritty)
            # Alacritty has no tabs - open new window instead
            alacritty msg create-window --working-directory "$dir" 2>/dev/null || \
            alacritty --working-directory "$dir" &
            ;;
        *)
            echo -e "${YELLOW}Warning: Terminal '$terminal' not supported for tab opening${NC}" >&2
            echo -e "${YELLOW}Worktree path: $dir${NC}" >&2
            return 1
            ;;
    esac
}

# Check if a dependency is available
check_dep() {
    local cmd="$1"
    local note="$2"
    if command -v "$cmd" &>/dev/null; then
        printf "  %-14s ${GREEN}ok${NC}\n" "$cmd"
    else
        printf "  %-14s ${YELLOW}not found${NC} (%s)\n" "$cmd" "$note"
    fi
}

# Display health check and terminal detection info
health_check() {
    local terminal=$(detect_terminal)
    echo -e "${BOLD}Terminal:${NC} $terminal"

    # Tab support info
    case "$terminal" in
        iterm2|terminal.app) echo -e "${BOLD}Tab support:${NC} yes (AppleScript)" ;;
        ghostty)             echo -e "${BOLD}Tab support:${NC} yes (open -a)" ;;
        kitty)               echo -e "${BOLD}Tab support:${NC} yes (kitten @)" ;;
        wezterm)             echo -e "${BOLD}Tab support:${NC} yes (wezterm cli)" ;;
        alacritty)           echo -e "${BOLD}Tab support:${NC} no (opens windows instead)" ;;
        *)                   echo -e "${BOLD}Tab support:${NC} unknown" ;;
    esac

    echo ""
    echo -e "${BOLD}Dependencies:${NC}"

    # Required
    check_dep "git" "required"

    # Platform-specific
    if [[ "$OSTYPE" == darwin* ]]; then
        check_dep "osascript" "required for iTerm2/Terminal.app"
    fi

    # Optional terminal tools
    check_dep "kitten" "optional, for Kitty tab support"
    check_dep "wezterm" "optional, for WezTerm tab support"

    echo ""
    echo -e "${BOLD}Epic dependencies (for wt epic):${NC}"
    check_dep "tmux" "required, terminal multiplexer"
    check_dep "jq" "required, JSON processor"
    check_dep "claude" "required, Claude CLI with Linear MCP"
    check_dep "gh" "optional, for PR creation"
}

print_usage() {
    echo "Usage: wt [-o] [--no-hooks] <command> [worktree-name] [branch-name]"
    echo ""
    echo "Manages git worktrees within the current repository's .worktrees/ directory."
    echo "Run this command from anywhere inside a git repository."
    echo ""
    echo "Options:"
    echo "  -o                      - Open: cd to worktree directory after create"
    echo "  --no-hooks              - Skip on-create hook execution"
    echo ""
    echo "Commands:"
    echo "  create <name> [branch]  - Create a new worktree (branch defaults to configured base)"
    echo "  list [--all]            - List worktrees (--all shows all git worktrees)"
    echo "  remove <name>           - Remove a worktree"
    echo "  open <name>             - cd to worktree directory"
    echo "  open --all              - Open all worktrees in new terminal tabs"
    echo "  exit [--force]          - Exit current worktree (removes it, returns to base)"
    echo "  health                  - Show terminal detection and dependency status"
    echo "  config                  - Show config for current repo"
    echo "  config base <branch>    - Set base branch for current repo"
    echo "  config base --global <branch> - Set global default base branch"
    echo "  config on-create <cmd>  - Set on-create hook for current repo"
    echo "  config on-create --unset - Remove on-create hook"
    echo "  config --list           - List all configuration"
    echo "  epic <issue-id>         - Spawn worktrees for Linear epic sub-tasks"
    echo "  epic status <issue-id>  - Show status of epic tasks"
    echo "  epic attach <issue-id>  - Attach to epic tmux session"
    echo "  epic complete <task-id> - Mark task complete, merge, unlock dependents"
    echo "  epic merge <issue-id>   - Create PR from integration branch"
    echo "  epic cleanup <issue-id> - Remove epic worktrees and session"
    echo "  update [--force]        - Update wt to latest version"
    echo "  version                 - Show version info"
    echo "  which                   - Show path to wt script"
    echo ""
    echo "Examples:"
    echo "  wt create feature/auth/login"
    echo "  wt -o create feature-branch   # create and cd"
    echo "  wt create name --no-hooks     # skip hook"
    echo "  wt open feature/auth/login    # cd to existing"
    echo "  wt open --all                 # open all in tabs"
    echo "  wt config base origin/main    # set base branch"
    echo "  wt config on-create 'pnpm install'  # set hook"
    echo "  wt list"
    echo "  wt update"
    echo ""
    echo "Epic workflow (Linear integration):"
    echo "  wt -o create epic-LIN-123     # create integration worktree"
    echo "  wt epic LIN-123               # spawn task worktrees + tmux"
    echo "  wt epic status LIN-123        # check progress"
    echo "  wt epic complete LIN-456      # merge a completed task"
}

detect_repo() {
    if ! git rev-parse --show-toplevel &>/dev/null; then
        echo -e "${RED}Error: Not inside a git repository${NC}" >&2
        exit 1
    fi

    # Get the common git dir (shared across all worktrees)
    local git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    # If git-common-dir ends with .git, the base repo is its parent
    # If it ends with .git/worktrees/<name>, we're in a worktree
    if [[ "$git_common_dir" == */.git ]]; then
        # In the base repo
        REPO_DIR="${git_common_dir%/.git}"
    elif [[ "$git_common_dir" == */.git/worktrees/* ]]; then
        # In a worktree - base repo is parent of .git
        REPO_DIR="${git_common_dir%/.git/worktrees/*}"
    else
        # Fallback to show-toplevel
        REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
    fi

    # Resolve symlinks for consistent path comparison (e.g., /tmp -> /private/tmp on macOS)
    REPO_DIR=$(cd "$REPO_DIR" && pwd -P)
    WORKTREES_BASE_DIR="$REPO_DIR/.worktrees"
}

ensure_worktrees_excluded() {
    local exclude_file="$REPO_DIR/.git/info/exclude"
    if [ -f "$exclude_file" ]; then
        if ! grep -q "^\.worktrees$" "$exclude_file" 2>/dev/null; then
            echo ".worktrees" >> "$exclude_file"
        fi
    fi
}

# Configuration helpers
get_config_file() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wt"
    echo "$config_dir/config"
}

get_config_value() {
    local key="$1"
    local config_file=$(get_config_file)
    if [ -f "$config_file" ]; then
        grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2-
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    local config_file=$(get_config_file)
    local config_dir=$(dirname "$config_file")

    # Create config directory if needed
    mkdir -p "$config_dir"

    # Create file if it doesn't exist
    touch "$config_file"

    # Remove existing entry for this key
    local tmp_file=$(mktemp)
    grep -v "^${key}=" "$config_file" > "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$config_file"

    # Add new entry
    echo "${key}=${value}" >> "$config_file"
}

unset_config_value() {
    local key="$1"
    local config_file=$(get_config_file)

    if [ ! -f "$config_file" ]; then
        return
    fi

    local tmp_file=$(mktemp)
    grep -v "^${key}=" "$config_file" > "$tmp_file" 2>/dev/null || true
    mv "$tmp_file" "$config_file"
}

# Get the on_create hook for a repository
get_on_create_hook() {
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$repo_root" ]; then
        get_config_value "${repo_root}:on_create"
    fi
}

# Execute on-create hook in the worktree directory
run_on_create_hook() {
    local worktree_path="$1"
    local hook_command=$(get_on_create_hook)

    if [ -z "$hook_command" ]; then
        return 0
    fi

    echo -e "${BLUE}Running on-create hook: ${hook_command}${NC}" >&2

    # Run the hook command in the worktree directory
    if (cd "$worktree_path" && bash -c "$hook_command") >&2; then
        echo -e "${GREEN}Hook completed successfully${NC}" >&2
        return 0
    else
        local exit_code=$?
        echo -e "${YELLOW}Warning: Hook failed with exit code $exit_code${NC}" >&2
        return $exit_code
    fi
}

get_base_branch() {
    # Resolution order: repo-specific -> global default -> hardcoded default
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)

    # Try repo-specific config
    if [ -n "$repo_root" ]; then
        local repo_base=$(get_config_value "$repo_root")
        if [ -n "$repo_base" ]; then
            echo "$repo_base"
            return
        fi
    fi

    # Try global default
    local global_base=$(get_config_value "_default")
    if [ -n "$global_base" ]; then
        echo "$global_base"
        return
    fi

    # Hardcoded fallback
    echo "origin/main"
}

handle_config() {
    local subcommand="$1"
    shift || true

    case "$subcommand" in
        ""|"show")
            # Show config for current repo
            local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
            local repo_base=""
            local repo_hook=""
            local global_base=$(get_config_value "_default")

            if [ -n "$repo_root" ]; then
                repo_base=$(get_config_value "$repo_root")
                repo_hook=$(get_config_value "${repo_root}:on_create")
            fi

            if [ -n "$repo_base" ]; then
                echo -e "${BLUE}Repository base:${NC} $repo_base"
            fi
            if [ -n "$repo_hook" ]; then
                echo -e "${BLUE}On-create hook:${NC} $repo_hook"
            fi
            if [ -n "$global_base" ]; then
                echo -e "${BLUE}Global default:${NC} $global_base"
            fi
            if [ -z "$repo_base" ] && [ -z "$global_base" ] && [ -z "$repo_hook" ]; then
                echo -e "${YELLOW}No config set. Using default: origin/main${NC}"
            fi
            echo -e "${BLUE}Effective base branch:${NC} $(get_base_branch)"
            ;;
        "base")
            local is_global=false
            local is_unset=false
            local branch=""

            # Parse arguments
            while [ $# -gt 0 ]; do
                case "$1" in
                    --global|-g)
                        is_global=true
                        shift
                        ;;
                    --unset)
                        is_unset=true
                        shift
                        ;;
                    *)
                        branch="$1"
                        shift
                        ;;
                esac
            done

            if [ "$is_global" = true ]; then
                if [ "$is_unset" = true ]; then
                    unset_config_value "_default"
                    echo -e "${GREEN}Global default unset${NC}"
                elif [ -n "$branch" ]; then
                    set_config_value "_default" "$branch"
                    echo -e "${GREEN}Global default set to: $branch${NC}"
                else
                    local val=$(get_config_value "_default")
                    if [ -n "$val" ]; then
                        echo "$val"
                    else
                        echo -e "${YELLOW}No global default set${NC}"
                    fi
                fi
            else
                local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
                if [ -z "$repo_root" ]; then
                    echo -e "${RED}Error: Not inside a git repository${NC}" >&2
                    exit 1
                fi

                if [ "$is_unset" = true ]; then
                    unset_config_value "$repo_root"
                    echo -e "${GREEN}Config unset for: $repo_root${NC}"
                elif [ -n "$branch" ]; then
                    set_config_value "$repo_root" "$branch"
                    echo -e "${GREEN}Base branch set to: $branch${NC}"
                else
                    local val=$(get_config_value "$repo_root")
                    if [ -n "$val" ]; then
                        echo "$val"
                    else
                        echo -e "${YELLOW}No config set for this repository${NC}"
                    fi
                fi
            fi
            ;;
        "--list"|"-l")
            local config_file=$(get_config_file)
            if [ -f "$config_file" ] && [ -s "$config_file" ]; then
                echo -e "${BLUE}Configuration:${NC}"
                while IFS='=' read -r key value; do
                    if [ "$key" = "_default" ]; then
                        echo -e "  ${YELLOW}[global]${NC} base = $value"
                    elif [[ "$key" == *":on_create" ]]; then
                        local repo="${key%:on_create}"
                        echo -e "  $repo"
                        echo -e "    on-create = $value"
                    else
                        echo -e "  $key"
                        echo -e "    base = $value"
                    fi
                done < "$config_file"
            else
                echo -e "${YELLOW}No configuration set${NC}"
            fi
            ;;
        "on-create")
            local is_unset=false
            local command=""

            # Parse arguments - everything that's not --unset is the command
            while [ $# -gt 0 ]; do
                case "$1" in
                    --unset)
                        is_unset=true
                        shift
                        ;;
                    *)
                        if [ -z "$command" ]; then
                            command="$1"
                        else
                            command="$command $1"
                        fi
                        shift
                        ;;
                esac
            done

            local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
            if [ -z "$repo_root" ]; then
                echo -e "${RED}Error: Not inside a git repository${NC}" >&2
                exit 1
            fi

            if [ "$is_unset" = true ]; then
                unset_config_value "${repo_root}:on_create"
                echo -e "${GREEN}On-create hook unset for: $repo_root${NC}"
            elif [ -n "$command" ]; then
                set_config_value "${repo_root}:on_create" "$command"
                echo -e "${GREEN}On-create hook set to: $command${NC}"
            else
                local val=$(get_config_value "${repo_root}:on_create")
                if [ -n "$val" ]; then
                    echo "$val"
                else
                    echo -e "${YELLOW}No on-create hook set for this repository${NC}"
                fi
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown config subcommand '$subcommand'${NC}" >&2
            echo "Usage: wt config [base [--global] [--unset] [branch]] [on-create [--unset] [command]] [--list]" >&2
            exit 1
            ;;
    esac
}

# Get the current worktree name if we're inside one, empty otherwise
get_current_worktree() {
    local current_dir=$(pwd -P)  # Resolve symlinks

    # Check if we're under the .worktrees directory
    case "$current_dir" in
        "$WORKTREES_BASE_DIR"/*)
            # Walk up to find the worktree root (has .git file)
            local dir="$current_dir"
            while [[ "$dir" == "$WORKTREES_BASE_DIR"/* ]]; do
                if [[ -f "$dir/.git" ]]; then
                    # Found the worktree root, extract relative path
                    echo "${dir#$WORKTREES_BASE_DIR/}"
                    return 0
                fi
                dir=$(dirname "$dir")
            done
            ;;
    esac

    return 1
}

# Check if worktree has uncommitted changes
is_worktree_dirty() {
    local worktree_path="$1"
    git -C "$worktree_path" status --porcelain 2>/dev/null | grep -q .
}

# Get list of worktree names in .worktrees (handles nested paths like feature/auth/login)
get_worktree_names() {
    if [ ! -d "$WORKTREES_BASE_DIR" ]; then
        return
    fi
    # Use git worktree list and filter for .worktrees paths
    git worktree list --porcelain 2>/dev/null | grep "^worktree " | cut -d' ' -f2- | while read -r path; do
        case "$path" in
            "$WORKTREES_BASE_DIR"*)
                echo "${path#$WORKTREES_BASE_DIR/}"
                ;;
        esac
    done
}

# Check if a worktree has uncommitted changes
is_worktree_dirty() {
    local worktree_path="$1"
    # Check if worktree has uncommitted changes (staged or unstaged)
    git -C "$worktree_path" status --porcelain 2>/dev/null | grep -q .
}

# Resolve worktree name to full path
resolve_worktree_path() {
    local name="$1"
    local path="$WORKTREES_BASE_DIR/$name"

    # Check if it exists in .worktrees
    if [ -d "$path" ] && [ -f "$path/.git" ]; then
        echo "$path"
        return 0
    fi

    return 1
}

create_worktree() {
    local name="$1"
    local branch="${2:-$name}"
    local worktree_path="$WORKTREES_BASE_DIR/$name"

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Worktree name is required${NC}" >&2
        print_usage >&2
        exit 1
    fi

    if [ -d "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$name' already exists at $worktree_path${NC}" >&2
        exit 1
    fi

    echo -e "${BLUE}Creating worktree '$name' from branch '$branch'...${NC}" >&2

    # Ensure .worktrees is in .git/info/exclude
    ensure_worktrees_excluded

    # Create the base directory if it doesn't exist
    mkdir -p "$WORKTREES_BASE_DIR"

    # Change to repository directory and create worktree
    cd "$REPO_DIR"

    # If using default branch name (same as worktree), check if branch exists
    # Redirect git output to stderr so it doesn't interfere with cd command
    if [ "$branch" = "$name" ]; then
        # Check if branch exists locally or remotely
        if git show-ref --verify --quiet "refs/heads/$name" || git show-ref --verify --quiet "refs/remotes/origin/$name"; then
            echo -e "${YELLOW}Using existing branch '$name'${NC}" >&2
            git worktree add "$worktree_path" "$name" >&2
        else
            local base_branch=$(get_base_branch)
            echo -e "${YELLOW}Creating new branch '$name' from $base_branch${NC}" >&2
            git worktree add -b "$name" "$worktree_path" "$base_branch" >&2
            # Configure push to use same branch name on remote
            git -C "$worktree_path" config push.autoSetupRemote true
            git -C "$worktree_path" branch --unset-upstream 2>/dev/null || true
        fi
    else
        git worktree add "$worktree_path" "$branch" >&2
    fi

    echo -e "${GREEN}Worktree created successfully!${NC}" >&2
    echo -e "${YELLOW}Path: $worktree_path${NC}" >&2

    # Run on-create hook unless --no-hooks was specified
    if [ "$NO_HOOKS" != "true" ]; then
        run_on_create_hook "$worktree_path" || true
    fi

    if [ "$OPEN_AFTER" = "true" ]; then
        open_worktree "$name"
    else
        echo -e "${YELLOW}To open: wt open $name${NC}" >&2
    fi
}

list_worktrees() {
    local show_all="$1"

    if [ "$show_all" = "--all" ]; then
        echo -e "${BLUE}All git worktrees:${NC}"
        cd "$REPO_DIR"
        git worktree list
    else
        local worktrees=$(get_worktree_names)
        if [ -z "$worktrees" ]; then
            echo "No worktrees found in .worktrees/"
        else
            echo "$worktrees"
        fi
    fi
}

remove_worktree() {
    local pattern="$1"
    local force="$2"

    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: Worktree name or pattern is required${NC}" >&2
        print_usage >&2
        exit 1
    fi

    # Convert glob to regex: * -> .*, ? -> .
    local regex=$(echo "$pattern" | sed 's/\*/.\*/g; s/?/./g')

    # Get matching worktrees
    local matches=$(get_worktree_names | grep -E "^${regex}$" 2>/dev/null)

    # If no regex match, try exact match for backwards compatibility
    if [ -z "$matches" ]; then
        local worktree_path=$(resolve_worktree_path "$pattern")
        if [ -n "$worktree_path" ]; then
            matches="$pattern"
        fi
    fi

    if [ -z "$matches" ]; then
        echo -e "${RED}Error: No worktrees match '$pattern'${NC}" >&2
        exit 1
    fi

    # Count matches
    local count=$(echo "$matches" | wc -l | tr -d ' ')

    # Show what will be removed
    echo -e "${YELLOW}Removing $count worktree(s):${NC}" >&2
    echo "$matches" | while read -r name; do
        echo "  - $name" >&2
    done

    # Remove each
    cd "$REPO_DIR"
    echo "$matches" | while read -r name; do
        local path="$WORKTREES_BASE_DIR/$name"
        git worktree remove $force "$path" >&2
    done

    echo -e "${GREEN}Done!${NC}" >&2
}

open_worktree() {
    local name="$1"
    local open_all=false

    # Check for --all flag
    if [ "$name" = "--all" ]; then
        open_all=true
    fi

    if $open_all; then
        local worktrees=$(get_worktree_names)
        if [ -z "$worktrees" ]; then
            echo -e "${YELLOW}No worktrees found${NC}" >&2
            exit 0
        fi

        local count=0
        while IFS= read -r wt_name; do
            local wt_path=$(resolve_worktree_path "$wt_name")
            if [ -n "$wt_path" ]; then
                if open_terminal_tab "$wt_path"; then
                    echo -e "${GREEN}Opened: $wt_name${NC}" >&2
                    ((count++))
                fi
            fi
        done <<< "$worktrees"

        echo -e "${GREEN}Opened $count worktree(s) in new tabs${NC}" >&2
        return 0
    fi

    # Original single-worktree logic
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Worktree name is required${NC}" >&2
        print_usage >&2
        exit 1
    fi

    local worktree_path=$(resolve_worktree_path "$name")
    if [ -z "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$name' does not exist${NC}" >&2
        exit 1
    fi

    # Output cd command for eval (stdout only)
    echo "cd \"$worktree_path\""
}

exit_worktree() {
    local force="$1"
    local force_flag=""
    [[ "$force" == "--force" || "$force" == "-f" ]] && force_flag="--force"

    local current_worktree=$(get_current_worktree)

    if [ -z "$current_worktree" ]; then
        echo -e "${RED}Error: Not in a worktree. Use 'wt exit' from within a worktree.${NC}" >&2
        exit 1
    fi

    local worktree_path="$WORKTREES_BASE_DIR/$current_worktree"

    # Check for uncommitted changes
    if is_worktree_dirty "$worktree_path" && [ -z "$force_flag" ]; then
        echo -e "${RED}Error: Worktree has uncommitted changes. Use --force to remove anyway.${NC}" >&2
        exit 1
    fi

    echo -e "${YELLOW}Exiting worktree: $current_worktree${NC}" >&2

    # Output cd command for shell wrapper
    echo "cd \"$REPO_DIR\""

    # Remove the worktree
    cd "$REPO_DIR"
    git worktree remove $force_flag "$worktree_path" >&2
    echo -e "${GREEN}Done!${NC}" >&2
}

# Check if we're in a worktree (not the root repo)
is_in_worktree() {
    local current_dir=$(pwd -P)
    case "$current_dir" in
        "$WORKTREES_BASE_DIR"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Handle epic command and subcommands
handle_epic() {
    local subcommand="$1"
    shift || true

    # Check for required tools
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq is required for wt epic. Install it with your package manager.${NC}" >&2
        exit 1
    fi

    check_tmux || exit 1

    case "$subcommand" in
        ""|"-h"|"--help")
            echo "Usage: wt epic <issue-id> [options]"
            echo "       wt epic <subcommand> <args>"
            echo ""
            echo "Subcommands:"
            echo "  <issue-id>              - Spawn worktrees for Linear epic (must run from worktree)"
            echo "  status <issue-id>       - Show status of epic tasks"
            echo "  attach <issue-id>       - Attach to epic tmux session"
            echo "  complete <task-id>      - Mark task complete, merge, unlock dependents"
            echo "  merge <issue-id>        - Create PR from integration branch"
            echo "  cleanup <issue-id>      - Remove epic worktrees and session"
            echo ""
            echo "Options:"
            echo "  --dry-run               - Preview what would be created"
            echo "  --workers N             - Limit concurrent sessions (default: 5)"
            ;;
        status)
            epic_status "$@"
            ;;
        attach)
            epic_attach "$@"
            ;;
        complete)
            epic_complete "$@"
            ;;
        merge)
            epic_merge "$@"
            ;;
        cleanup)
            epic_cleanup "$@"
            ;;
        *)
            # Treat as epic ID - spawn workflow
            epic_spawn "$subcommand" "$@"
            ;;
    esac
}

# wt epic <issue-id> - main spawn workflow
epic_spawn() {
    local epic_id="$1"
    shift || true

    local dry_run=false
    local max_workers=5

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --workers)
                max_workers="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                exit 1
                ;;
        esac
    done

    # Validate: must be in a worktree
    if ! is_in_worktree; then
        echo -e "${RED}Error: Must run 'wt epic' from within a worktree.${NC}" >&2
        echo -e "${YELLOW}The current worktree becomes the integration branch for merges.${NC}" >&2
        echo "" >&2
        echo "First create an integration worktree:" >&2
        echo "  wt -o create epic-${epic_id}" >&2
        echo "" >&2
        echo "Then from within that worktree:" >&2
        echo "  wt epic ${epic_id}" >&2
        exit 1
    fi

    # Check if epic already exists
    if epic_state_exists "$epic_id"; then
        echo -e "${YELLOW}Epic '$epic_id' already exists. Use 'wt epic status $epic_id' or 'wt epic cleanup $epic_id' first.${NC}" >&2
        exit 1
    fi

    local integration_branch=$(git branch --show-current)
    echo -e "${BLUE}Fetching epic data from Linear...${NC}" >&2

    # Fetch epic data from Linear
    local epic_data
    epic_data=$(fetch_epic_data "$epic_id")
    if [ $? -ne 0 ] || [ -z "$epic_data" ]; then
        echo -e "${RED}Error: Failed to fetch epic data from Linear${NC}" >&2
        exit 1
    fi

    local epic_title=$(echo "$epic_data" | jq -r '.epic.title')
    local tasks=$(echo "$epic_data" | jq -r '.tasks')
    local task_count=$(echo "$tasks" | jq 'length')

    echo -e "${GREEN}Epic:${NC} $epic_title" >&2
    echo -e "${BLUE}Found $task_count sub-tasks${NC}" >&2
    echo "" >&2

    if [ "$dry_run" = true ]; then
        echo -e "${YELLOW}Dry run - would create:${NC}" >&2
        echo "$tasks" | jq -r '.[] | "  - \(.identifier): \(.title)"' >&2
        echo "" >&2
        echo "Integration branch: $integration_branch" >&2
        echo "tmux session: wt-epic-${epic_id}" >&2
        exit 0
    fi

    # Build initial state for tasks
    local tasks_state="[]"
    for task in $(echo "$tasks" | jq -c '.[]'); do
        local task_id=$(echo "$task" | jq -r '.id')
        local identifier=$(echo "$task" | jq -r '.identifier')
        local title=$(echo "$task" | jq -r '.title')
        local blocked_by=$(echo "$task" | jq -r '.blockedBy // []')

        local status="pending"
        if [ "$(echo "$blocked_by" | jq 'length')" -gt 0 ]; then
            status="blocked"
        fi

        tasks_state=$(echo "$tasks_state" | jq --arg id "$task_id" \
            --arg identifier "$identifier" \
            --arg title "$title" \
            --arg status "$status" \
            --argjson blockedBy "$blocked_by" \
            --arg worktree ".worktrees/$identifier" \
            '. + [{
                issueId: $id,
                identifier: $identifier,
                title: $title,
                status: $status,
                blockedBy: $blockedBy,
                worktree: $worktree,
                paneId: null
            }]')
    done

    # Create epic state
    local state=$(create_epic_state "$epic_id" "$integration_branch" "$tasks_state")

    # Create tmux session
    local session_name=$(create_epic_session "$epic_id")
    echo -e "${GREEN}Created tmux session:${NC} $session_name" >&2

    # Create worktrees and spawn panes for unblocked tasks
    local spawned=0
    for task in $(echo "$tasks" | jq -c '.[]'); do
        local identifier=$(echo "$task" | jq -r '.identifier')
        local title=$(echo "$task" | jq -r '.title')
        local blocked_by=$(echo "$task" | jq -r '.blockedBy // []')
        local is_blocked=$(echo "$blocked_by" | jq 'length > 0')

        # Create worktree (branch from integration branch)
        local worktree_path="$WORKTREES_BASE_DIR/$identifier"

        echo -e "${BLUE}Creating worktree for $identifier...${NC}" >&2

        # Create worktree branching from current (integration) branch
        if [ ! -d "$worktree_path" ]; then
            git worktree add -b "$identifier" "$worktree_path" HEAD >&2 2>/dev/null || \
                git worktree add "$worktree_path" "$identifier" >&2
        fi

        # Generate context file
        local context_file=$(generate_task_context "$task" "$integration_branch" "$worktree_path")

        if [ "$is_blocked" = "true" ]; then
            # Create waiting pane for blocked tasks
            local blocked_list=$(echo "$blocked_by" | jq -r 'join(", ")')
            add_waiting_pane "$session_name" "$identifier" "$worktree_path" "$blocked_list" >/dev/null
            update_task_status "$epic_id" "$identifier" "blocked"
            echo -e "${YELLOW}  [$identifier] blocked by: $blocked_list${NC}" >&2
        else
            # Spawn active pane for unblocked tasks
            if [ $spawned -lt $max_workers ]; then
                local pane_id=$(add_task_pane "$session_name" "$identifier" "$worktree_path" "$context_file")
                set_task_pane "$epic_id" "$identifier" "$pane_id"
                update_task_status "$epic_id" "$identifier" "in_progress"
                spawned=$((spawned + 1))
                echo -e "${GREEN}  [$identifier] spawned${NC}" >&2
            else
                echo -e "${YELLOW}  [$identifier] queued (max workers reached)${NC}" >&2
            fi
        fi
    done

    echo "" >&2
    echo -e "${GREEN}Epic spawned successfully!${NC}" >&2
    echo -e "${BLUE}Attach to session:${NC} wt epic attach $epic_id" >&2
    echo -e "${BLUE}Check status:${NC} wt epic status $epic_id" >&2
}

# wt epic status <issue-id>
epic_status() {
    local epic_id="$1"

    if [ -z "$epic_id" ]; then
        echo -e "${RED}Error: Epic ID required${NC}" >&2
        echo "Usage: wt epic status <issue-id>" >&2
        exit 1
    fi

    local state=$(load_epic_state "$epic_id")
    if [ -z "$state" ]; then
        echo -e "${RED}Error: No epic found with ID '$epic_id'${NC}" >&2
        echo "Start an epic with: wt epic $epic_id" >&2
        exit 1
    fi

    print_epic_status "$state"

    # Check tmux session
    local tmux_session=$(echo "$state" | jq -r '.tmuxSession')
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}tmux session active${NC}"
        echo "Attach with: wt epic attach $epic_id"
    else
        echo ""
        echo -e "${YELLOW}tmux session not running${NC}"
    fi
}

# wt epic attach <issue-id>
epic_attach() {
    local epic_id="$1"

    if [ -z "$epic_id" ]; then
        echo -e "${RED}Error: Epic ID required${NC}" >&2
        echo "Usage: wt epic attach <issue-id>" >&2
        exit 1
    fi

    attach_epic_session "$epic_id"
}

# wt epic complete <task-id>
epic_complete() {
    local task_id="$1"

    if [ -z "$task_id" ]; then
        echo -e "${RED}Error: Task ID required${NC}" >&2
        echo "Usage: wt epic complete <task-id>" >&2
        exit 1
    fi

    # Find which epic this task belongs to
    local epics_dir=$(get_epics_dir)
    local epic_id=""
    local state=""

    if [ -d "$epics_dir" ]; then
        for state_file in "$epics_dir"/*.json; do
            [ -f "$state_file" ] || continue
            local file_state=$(cat "$state_file")
            local task=$(echo "$file_state" | jq -r --arg id "$task_id" '.tasks[] | select(.identifier == $id)')
            if [ -n "$task" ] && [ "$task" != "null" ]; then
                epic_id=$(echo "$file_state" | jq -r '.epicId')
                state="$file_state"
                break
            fi
        done
    fi

    if [ -z "$epic_id" ]; then
        echo -e "${RED}Error: Task '$task_id' not found in any epic${NC}" >&2
        exit 1
    fi

    local task=$(get_task_state "$state" "$task_id")
    local worktree=$(echo "$task" | jq -r '.worktree')
    local worktree_path="$REPO_DIR/$worktree"
    local integration_branch=$(echo "$state" | jq -r '.integrationBranch')

    # Check if task has commits
    echo -e "${BLUE}Merging $task_id into $integration_branch...${NC}" >&2

    # Get the integration worktree path
    local integration_worktree=""
    for wt in $(get_worktree_names); do
        local wt_path="$WORKTREES_BASE_DIR/$wt"
        local wt_branch=$(git -C "$wt_path" branch --show-current 2>/dev/null)
        if [ "$wt_branch" = "$integration_branch" ]; then
            integration_worktree="$wt_path"
            break
        fi
    done

    if [ -z "$integration_worktree" ]; then
        echo -e "${RED}Error: Could not find integration worktree for branch '$integration_branch'${NC}" >&2
        exit 1
    fi

    # Merge task branch into integration branch
    cd "$integration_worktree"
    if git merge --no-ff "$task_id" -m "Merge $task_id: $(echo "$task" | jq -r '.title')"; then
        echo -e "${GREEN}Merged $task_id successfully${NC}" >&2
        update_task_status "$epic_id" "$task_id" "completed"

        # Update Linear status
        update_linear_status "$task_id" "Done" 2>/dev/null || true

        # Check for newly unblocked tasks
        state=$(load_epic_state "$epic_id")
        local unblocked=$(get_newly_unblocked_tasks "$state")
        local unblocked_count=$(echo "$unblocked" | jq 'length')

        if [ "$unblocked_count" -gt 0 ]; then
            echo -e "${BLUE}Unlocking $unblocked_count dependent task(s)...${NC}" >&2

            local session_name="wt-epic-${epic_id}"
            for task in $(echo "$unblocked" | jq -c '.[]'); do
                local dep_id=$(echo "$task" | jq -r '.identifier')
                local dep_worktree="$WORKTREES_BASE_DIR/$dep_id"
                local context_file="$dep_worktree/.claude-context"

                update_task_status "$epic_id" "$dep_id" "in_progress"
                activate_task_pane "$session_name" "$dep_id" "$context_file"
                echo -e "${GREEN}  Activated: $dep_id${NC}" >&2
            done
        fi
    else
        echo -e "${RED}Merge failed. Resolve conflicts and try again.${NC}" >&2
        exit 1
    fi
}

# wt epic merge <issue-id>
epic_merge() {
    local epic_id="$1"

    if [ -z "$epic_id" ]; then
        echo -e "${RED}Error: Epic ID required${NC}" >&2
        echo "Usage: wt epic merge <issue-id>" >&2
        exit 1
    fi

    local state=$(load_epic_state "$epic_id")
    if [ -z "$state" ]; then
        echo -e "${RED}Error: No epic found with ID '$epic_id'${NC}" >&2
        exit 1
    fi

    local integration_branch=$(echo "$state" | jq -r '.integrationBranch')
    local incomplete=$(get_tasks_by_status "$state" "in_progress")
    local incomplete_count=$(echo "$incomplete" | jq 'length')

    if [ "$incomplete_count" -gt 0 ]; then
        echo -e "${YELLOW}Warning: $incomplete_count task(s) still in progress${NC}" >&2
        echo "$incomplete" | jq -r '.[] | "  - \(.identifier): \(.title)"' >&2
        echo "" >&2
    fi

    # Find integration worktree
    local integration_worktree=""
    for wt in $(get_worktree_names); do
        local wt_path="$WORKTREES_BASE_DIR/$wt"
        local wt_branch=$(git -C "$wt_path" branch --show-current 2>/dev/null)
        if [ "$wt_branch" = "$integration_branch" ]; then
            integration_worktree="$wt_path"
            break
        fi
    done

    if [ -z "$integration_worktree" ]; then
        echo -e "${RED}Error: Could not find integration worktree${NC}" >&2
        exit 1
    fi

    cd "$integration_worktree"

    # Push branch and create PR using gh
    echo -e "${BLUE}Pushing $integration_branch...${NC}" >&2
    git push -u origin "$integration_branch" >&2

    local base_branch=$(get_base_branch)
    local epic_title=$(echo "$state" | jq -r '.epicId')

    echo -e "${BLUE}Creating PR...${NC}" >&2

    # Get completed task list for PR body
    local completed=$(get_tasks_by_status "$state" "completed")
    local task_list=$(echo "$completed" | jq -r '.[] | "- [x] \(.identifier): \(.title)"')

    gh pr create \
        --base "${base_branch#origin/}" \
        --head "$integration_branch" \
        --title "Epic: $epic_id" \
        --body "## Tasks

$task_list

---
Created with \`wt epic\`"

    echo -e "${GREEN}PR created!${NC}" >&2
}

# wt epic cleanup <issue-id>
epic_cleanup() {
    local epic_id="$1"
    local force=""

    shift || true
    [ "$1" = "--force" ] || [ "$1" = "-f" ] && force="--force"

    if [ -z "$epic_id" ]; then
        echo -e "${RED}Error: Epic ID required${NC}" >&2
        echo "Usage: wt epic cleanup <issue-id> [--force]" >&2
        exit 1
    fi

    local state=$(load_epic_state "$epic_id")
    if [ -z "$state" ]; then
        echo -e "${RED}Error: No epic found with ID '$epic_id'${NC}" >&2
        exit 1
    fi

    echo -e "${YELLOW}Cleaning up epic '$epic_id'...${NC}" >&2

    # Kill tmux session
    kill_epic_session "$epic_id"

    # Remove task worktrees
    local tasks=$(echo "$state" | jq -c '.tasks[]')
    while IFS= read -r task; do
        local identifier=$(echo "$task" | jq -r '.identifier')
        local worktree_path="$WORKTREES_BASE_DIR/$identifier"

        if [ -d "$worktree_path" ]; then
            # Check for uncommitted changes
            if is_worktree_dirty "$worktree_path" && [ -z "$force" ]; then
                echo -e "${YELLOW}  Skipping $identifier (has uncommitted changes, use --force)${NC}" >&2
                continue
            fi

            echo -e "${BLUE}  Removing worktree: $identifier${NC}" >&2
            git worktree remove $force "$worktree_path" 2>/dev/null || \
                echo -e "${YELLOW}  Failed to remove $identifier${NC}" >&2
        fi
    done <<< "$tasks"

    # Delete state file
    delete_epic_state "$epic_id"

    echo -e "${GREEN}Epic cleanup complete${NC}" >&2
}

get_version() {
    local manifest="$INSTALL_DIR/manifest.toml"
    if [ -f "$manifest" ]; then
        grep '^version' "$manifest" | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

show_version() {
    local version=$(get_version)
    echo -e "${BLUE}wt${NC} $version"
}

update_worktree() {
    local force="$1"

    if [ ! -d "$INSTALL_DIR/.git" ]; then
        echo -e "${RED}Error: Install directory is not a git repository${NC}"
        echo "Reinstall with: curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash"
        exit 1
    fi

    local old_version=$(get_version)
    echo -e "${BLUE}Updating wt...${NC}"

    cd "$INSTALL_DIR"

    if [ "$force" = "--force" ] || [ "$force" = "-f" ]; then
        echo -e "${YELLOW}Force updating...${NC}"
        git fetch origin main
        git reset --hard origin/main
    else
        git pull --ff-only origin main
    fi

    local new_version=$(get_version)
    if [ "$old_version" = "$new_version" ]; then
        echo -e "${GREEN}Already up to date ($new_version)${NC}"
    else
        echo -e "${GREEN}Updated: $old_version -> $new_version${NC}"
    fi
}

# Parse arguments
OPEN_AFTER="false"
NO_HOOKS="false"

# Check for flags
while [[ "$1" == -* ]]; do
    case "$1" in
        -o)
            OPEN_AFTER="true"
            shift
            ;;
        --no-hooks)
            NO_HOOKS="true"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown flag $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Commands that don't need a git repo
case "$1" in
update)
    update_worktree "$2"
    exit 0
    ;;
version)
    show_version
    exit 0
    ;;
which)
    # Show path to this script
    echo "$0"
    exit 0
    ;;
health)
    health_check
    exit 0
    ;;
esac

# All other commands need a git repo
detect_repo

case "$1" in
create)
    # Handle -o and --no-hooks flags in any position
    _name="" _branch=""
    shift  # remove 'create'
    for arg in "$@"; do
        if [[ "$arg" == "-o" ]]; then
            OPEN_AFTER="true"
        elif [[ "$arg" == "--no-hooks" ]]; then
            NO_HOOKS="true"
        elif [[ -z "$_name" ]]; then
            _name="$arg"
        else
            _branch="$arg"
        fi
    done
    create_worktree "$_name" "$_branch"
    ;;
list)
    list_worktrees "$2"
    ;;
remove)
    _pattern="" _force=""
    shift  # remove 'remove'
    for arg in "$@"; do
        if [[ "$arg" == "--force" ]] || [[ "$arg" == "-f" ]]; then
            _force="--force"
        elif [[ -z "$_pattern" ]]; then
            _pattern="$arg"
        fi
    done
    remove_worktree "$_pattern" "$_force"
    ;;
open)
    open_worktree "$2"
    ;;
exit)
    exit_worktree "$2"
    ;;
config)
    shift  # remove 'config'
    handle_config "$@"
    ;;
epic)
    shift  # remove 'epic'
    handle_epic "$@"
    ;;
*)
    print_usage
    exit 1
    ;;
esac
