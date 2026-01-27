#!/bin/bash

# Git Worktree Setup Script for Multiple Claude Code Instances
# This script helps create separate git worktrees for working with multiple
# instances of Claude Code on any git repository

set -e

# Install location (set by installer)
INSTALL_DIR="${WORKTREE_INSTALL_DIR:-$HOME/.local/share/worktree}"

# Source library files
LIB_DIR="$INSTALL_DIR/lib"
[ -f "$LIB_DIR/config.sh" ] && source "$LIB_DIR/config.sh"
[ -f "$LIB_DIR/tmux.sh" ] && source "$LIB_DIR/tmux.sh"
[ -f "$LIB_DIR/spawn.sh" ] && source "$LIB_DIR/spawn.sh"
[ -f "$LIB_DIR/init.sh" ] && source "$LIB_DIR/init.sh"

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
    echo -e "${BOLD}Spawn dependencies (for wt spawn):${NC}"
    check_dep "tmux" "required, terminal multiplexer"
    check_dep "jq" "required, JSON processor"
    check_dep "claude" "required, Claude CLI"
    check_dep "gh" "optional, for PR creation"
}

print_usage() {
    echo "Usage: wt [-o] [--no-hooks] <command> [args...]"
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
    echo "  update [--force]        - Update wt to latest version"
    echo "  version                 - Show version info"
    echo "  which                   - Show path to wt script"
    echo ""
    echo "Spawn commands (multi-agent workflow):"
    echo "  spawn <name> [options]  - Create worktree + launch Claude in tmux"
    echo "    --context <text>      - Task context for Claude"
    echo "    --auto                - Auto-start Claude with prompt"
    echo "  ps                      - Show status of spawned sessions"
    echo "  attach [name]           - Attach to tmux session (optionally to specific window)"
    echo "  review <name>           - Show diff for parent review"
    echo "  merge <name>            - Merge reviewed worktree into current branch"
    echo "  kill <name>             - Kill a running tmux window"
    echo "  init [--force] [--backup] [--audit] - Initialize wt.toml, docs/, issues/, and .claude/"
    echo ""
    echo "Examples:"
    echo "  wt create feature/auth/login"
    echo "  wt -o create feature-branch   # create and cd"
    echo "  wt create name --no-hooks     # skip hook"
    echo "  wt open feature/auth/login    # cd to existing"
    echo "  wt open --all                 # open all in tabs"
    echo "  wt config base origin/main    # set base branch"
    echo "  wt config on-create 'pnpm install'  # set hook"
    echo ""
    echo "Spawn workflow (parallel Claude agents):"
    echo "  wt -o create epic-123         # create integration worktree"
    echo "  wt spawn AUT-456 --context 'Implement feature X...'  # spawn worker"
    echo "  wt spawn AUT-456 --context 'Implement...' --auto     # auto-start"
    echo "  wt ps                         # check status"
    echo "  wt attach                     # watch workers in tmux"
    echo "  wt review AUT-456             # review completed work"
    echo "  wt merge AUT-456              # merge into current branch"
    echo "  wt init                       # initialize wt for this repo"
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

    # Current toplevel: the worktree root if in a worktree, otherwise the base repo.
    # Used by commands that operate on the current directory (init, spawn).
    TOPLEVEL_DIR=$(cd "$(git rev-parse --show-toplevel 2>/dev/null)" && pwd -P)
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

# Handle spawn command - create worktree + launch Claude in tmux
handle_spawn() {
    local name="$1"
    shift || true

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Name is required${NC}" >&2
        echo "Usage: wt spawn <name> [--context <text>] [--auto]" >&2
        exit 1
    fi

    local context=""
    local auto_mode=false

    # Parse options first (before dependency checks)
    while [ $# -gt 0 ]; do
        case "$1" in
            --context|-c)
                context="$2"
                shift 2
                ;;
            --auto)
                auto_mode=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                exit 1
                ;;
        esac
    done

    # Check for required tools
    check_tmux || exit 1

    # Check if auto mode is configured in wt.toml (check current toplevel first, then base repo)
    local toml_dir="$TOPLEVEL_DIR"
    has_wt_toml "$toml_dir" || toml_dir="$REPO_DIR"
    if has_wt_toml "$toml_dir"; then
        local config_auto
        config_auto=$(get_wt_config "spawn.auto" "$toml_dir") || true
        [ "$config_auto" = "true" ] && auto_mode=true
    fi

    local worktree_path="$WORKTREES_BASE_DIR/$name"
    local current_branch=$(git branch --show-current 2>/dev/null || echo "HEAD")

    # Create worktree if it doesn't exist
    if [ ! -d "$worktree_path" ]; then
        echo -e "${BLUE}Creating worktree '$name' from '$current_branch'...${NC}" >&2

        ensure_worktrees_excluded
        mkdir -p "$WORKTREES_BASE_DIR"

        cd "$REPO_DIR"

        # Check if branch exists
        if git show-ref --verify --quiet "refs/heads/$name" || git show-ref --verify --quiet "refs/remotes/origin/$name"; then
            echo -e "${YELLOW}Using existing branch '$name'${NC}" >&2
            git worktree add "$worktree_path" "$name" >&2
        else
            echo -e "${YELLOW}Creating new branch '$name' from $current_branch${NC}" >&2
            git worktree add -b "$name" "$worktree_path" "$current_branch" >&2
            git -C "$worktree_path" config push.autoSetupRemote true
            git -C "$worktree_path" branch --unset-upstream 2>/dev/null || true
        fi

        # Run on-create hook
        if [ "$NO_HOOKS" != "true" ]; then
            run_on_create_hook "$worktree_path" || true
        fi
    else
        echo -e "${YELLOW}Worktree '$name' already exists${NC}" >&2
    fi

    # Write context file if provided (for non-auto mode)
    local context_file=""
    if [ -n "$context" ]; then
        context_file=$(write_context_file "$worktree_path" "$context")
        echo -e "${BLUE}Context written to .claude-task${NC}" >&2
    fi

    # Register as spawned
    register_spawn "$name" "$current_branch" "$context"

    # Build prompt for auto mode
    local prompt=""
    if [ "$auto_mode" = true ]; then
        prompt="$context"
        if [ -z "$prompt" ]; then
            echo -e "${YELLOW}Warning: No context for auto mode${NC}" >&2
            auto_mode=false
        else
            echo -e "${BLUE}Auto mode enabled${NC}" >&2
        fi
    fi

    # Launch in tmux
    spawn_window "$name" "$worktree_path" "$context_file" "$auto_mode" "$prompt"

    echo -e "${GREEN}Spawned '$name' in tmux session${NC}" >&2
    echo -e "${BLUE}Attach with:${NC} wt attach $name" >&2
}

# Handle ps command - show status of spawned sessions
handle_ps() {
    local spawned_names
    spawned_names=$(get_spawned_names)

    if [ -z "$spawned_names" ]; then
        echo "No spawned sessions"
        return 0
    fi

    # Print header
    printf "%-20s %-10s %-30s %-8s %-6s\n" "TASK" "STATUS" "BRANCH" "COMMITS" "DIRTY"
    printf "%-20s %-10s %-30s %-8s %-6s\n" "----" "------" "------" "-------" "-----"

    while IFS= read -r name; do
        [ -z "$name" ] && continue

        local worktree_path="$WORKTREES_BASE_DIR/$name"
        local status="unknown"
        local branch="-"
        local commits="-"
        local dirty="no"

        # Get tmux status
        status=$(get_window_status "$name")

        if [ -d "$worktree_path" ]; then
            # Get branch name
            branch=$(git -C "$worktree_path" branch --show-current 2>/dev/null || echo "-")

            # Count commits ahead of base
            local base_branch
            base_branch=$(get_base_branch)
            commits=$(git -C "$worktree_path" rev-list --count "${base_branch}..HEAD" 2>/dev/null || echo "0")

            # Check if dirty
            if is_worktree_dirty "$worktree_path"; then
                dirty="yes"
            fi
        fi

        printf "%-20s %-10s %-30s %-8s %-6s\n" "$name" "$status" "$branch" "$commits" "$dirty"
    done <<< "$spawned_names"
}

# Handle attach command - attach to tmux session
handle_attach() {
    local window_name="$1"

    check_tmux || exit 1

    attach_spawn "$window_name"
}

# Handle review command - show diff for parent review
handle_review() {
    local name="$1"
    local full_diff=false

    shift || true
    [ "$1" = "--full" ] && full_diff=true

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Name is required${NC}" >&2
        echo "Usage: wt review <name> [--full]" >&2
        exit 1
    fi

    local worktree_path="$WORKTREES_BASE_DIR/$name"

    if [ ! -d "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$name' does not exist${NC}" >&2
        exit 1
    fi

    local branch
    branch=$(git -C "$worktree_path" branch --show-current 2>/dev/null)
    local base_branch
    base_branch=$(get_base_branch)

    echo -e "${BOLD}Review: $name${NC}"
    echo -e "${BLUE}Branch:${NC} $branch"
    echo ""

    # Show commit count
    local commit_count
    commit_count=$(git -C "$worktree_path" rev-list --count "${base_branch}..HEAD" 2>/dev/null || echo "0")
    echo -e "${BLUE}Commits:${NC} $commit_count"
    echo ""

    # Show commit log
    if [ "$commit_count" -gt 0 ]; then
        echo -e "${BLUE}Commit history:${NC}"
        git -C "$worktree_path" log --oneline "${base_branch}..HEAD" 2>/dev/null || true
        echo ""
    fi

    # Show diff summary or full diff
    if [ "$full_diff" = true ]; then
        echo -e "${BLUE}Full diff:${NC}"
        git -C "$worktree_path" diff "${base_branch}...HEAD" 2>/dev/null || true
    else
        echo -e "${BLUE}Changed files:${NC}"
        git -C "$worktree_path" diff --stat "${base_branch}...HEAD" 2>/dev/null || true
        echo ""
        echo -e "${YELLOW}Use 'wt review $name --full' for complete diff${NC}"
    fi

    # Show if dirty
    if is_worktree_dirty "$worktree_path"; then
        echo ""
        echo -e "${YELLOW}Warning: Worktree has uncommitted changes${NC}"
    fi
}

# Handle merge command - merge reviewed worktree into current branch
handle_merge() {
    local name="$1"

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Name is required${NC}" >&2
        echo "Usage: wt merge <name>" >&2
        exit 1
    fi

    local worktree_path="$WORKTREES_BASE_DIR/$name"

    if [ ! -d "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree '$name' does not exist${NC}" >&2
        exit 1
    fi

    local source_branch
    source_branch=$(git -C "$worktree_path" branch --show-current 2>/dev/null)

    if [ -z "$source_branch" ]; then
        echo -e "${RED}Error: Could not determine branch for '$name'${NC}" >&2
        exit 1
    fi

    # Check for uncommitted changes in source
    if is_worktree_dirty "$worktree_path"; then
        echo -e "${RED}Error: Worktree '$name' has uncommitted changes${NC}" >&2
        echo "Commit or stash changes before merging." >&2
        exit 1
    fi

    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    echo -e "${BLUE}Merging '$source_branch' into '$current_branch'...${NC}" >&2

    # Perform merge
    if git merge --no-ff "$source_branch" -m "Merge $name: work from spawned session"; then
        echo -e "${GREEN}Merged '$name' successfully${NC}" >&2

        # Unregister from spawned state
        unregister_spawn "$name"

        # Kill tmux window if it exists
        kill_window "$name"

        echo ""
        echo -e "${YELLOW}Optionally remove the worktree with:${NC} wt remove $name"
    else
        echo -e "${RED}Merge failed. Resolve conflicts and try again.${NC}" >&2
        exit 1
    fi
}

# Handle kill command - kill a running tmux window
handle_kill() {
    local name="$1"

    if [ -z "$name" ]; then
        echo -e "${RED}Error: Name is required${NC}" >&2
        echo "Usage: wt kill <name>" >&2
        exit 1
    fi

    check_tmux || exit 1

    local status
    status=$(get_window_status "$name")

    if [ "$status" = "no_session" ] || [ "$status" = "no_window" ]; then
        echo -e "${YELLOW}No running session for '$name'${NC}" >&2
    else
        kill_window "$name"
        echo -e "${GREEN}Killed session for '$name'${NC}" >&2
    fi

    # Unregister from spawned state
    unregister_spawn "$name"
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

# Commands that don't need a git repo (or handle it themselves)
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
init|setup)
    shift  # remove 'init' or 'setup'
    handle_setup "$@"
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
spawn)
    shift  # remove 'spawn'
    handle_spawn "$@"
    ;;
ps)
    handle_ps
    ;;
attach)
    handle_attach "$2"
    ;;
review)
    shift  # remove 'review'
    handle_review "$@"
    ;;
merge)
    handle_merge "$2"
    ;;
kill)
    handle_kill "$2"
    ;;
*)
    print_usage
    exit 1
    ;;
esac
