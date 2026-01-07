#!/bin/bash

# Git Worktree Setup Script for Multiple Claude Code Instances
# This script helps create separate git worktrees for working with multiple
# instances of Claude Code on any git repository

set -e

# Install location (set by installer)
INSTALL_DIR="${WORKTREE_INSTALL_DIR:-$HOME/.local/share/worktree}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo "  cleanup                 - Remove all worktrees"
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
    echo "Examples:"
    echo "  wt create feature/auth/login"
    echo "  wt -o create feature-branch   # create and cd"
    echo "  wt create name --no-hooks     # skip hook"
    echo "  wt open feature/auth/login    # cd to existing"
    echo "  wt config base origin/main    # set base branch"
    echo "  wt config on-create 'pnpm install'  # set hook"
    echo "  wt list"
    echo "  wt update"
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
            # Extract the worktree name (first path component after .worktrees/)
            local relative="${current_dir#$WORKTREES_BASE_DIR/}"
            echo "${relative%%/*}"
            return 0
            ;;
    esac

    return 1
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

cleanup_worktrees() {
    local force="$1"
    local force_flag=""
    [[ "$force" == "--force" || "$force" == "-f" ]] && force_flag="--force"

    local current_worktree=$(get_current_worktree)

    if [ -n "$current_worktree" ]; then
        # In a worktree - remove just this one and return to base
        local worktree_path="$WORKTREES_BASE_DIR/$current_worktree"

        # Check if worktree is dirty
        if is_worktree_dirty "$worktree_path" && [ -z "$force_flag" ]; then
            echo -e "${RED}Error: Current worktree has uncommitted changes${NC}" >&2
            echo -e "Use ${YELLOW}wt cleanup --force${NC} to remove anyway" >&2
            exit 1
        fi

        echo -e "${YELLOW}Removing worktree: $current_worktree${NC}" >&2

        # Output cd command FIRST (so shell wrapper can eval it)
        echo "cd \"$REPO_DIR\""

        # Then remove the worktree (from base repo context)
        cd "$REPO_DIR"
        git worktree remove $force_flag "$worktree_path" >&2
        echo -e "${GREEN}Done!${NC}" >&2
    else
        # In base repo - existing behavior (remove all)
        echo -e "${YELLOW}Cleaning up all worktrees...${NC}" >&2

        if [ -d "$WORKTREES_BASE_DIR" ]; then
            cd "$REPO_DIR"

            local skipped=0
            # Remove all worktrees
            for worktree_dir in "$WORKTREES_BASE_DIR"/*; do
                if [ -d "$worktree_dir" ]; then
                    local name=$(basename "$worktree_dir")

                    # Check if worktree is dirty
                    if is_worktree_dirty "$worktree_dir" && [ -z "$force_flag" ]; then
                        echo -e "${YELLOW}Skipping${NC} $name (has uncommitted changes)" >&2
                        ((skipped++))
                        continue
                    fi

                    echo "Removing worktree: $name" >&2
                    git worktree remove $force_flag "$worktree_dir" 2>/dev/null || true
                fi
            done

            # Only remove the base directory if all worktrees were removed
            if [ "$skipped" -eq 0 ]; then
                rm -rf "$WORKTREES_BASE_DIR"
            fi

            if [ "$skipped" -gt 0 ]; then
                echo -e "${YELLOW}Skipped $skipped worktree(s) with uncommitted changes${NC}" >&2
                echo -e "Use ${YELLOW}wt cleanup --force${NC} to remove all" >&2
            fi
        fi

        echo -e "${GREEN}Cleanup complete!${NC}" >&2
    fi
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
cleanup)
    cleanup_worktrees "$2"
    ;;
config)
    shift  # remove 'config'
    handle_config "$@"
    ;;
*)
    print_usage
    exit 1
    ;;
esac
