#!/bin/bash

# Spawn state management for wt spawn command
# Tracks which worktrees were spawned with context

# Get the spawn state directory
get_spawn_dir() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wt"
    echo "$config_dir/spawned"
}

# Get path to repo-specific spawn state file
get_spawn_state_file() {
    local repo_root="$1"
    local hash
    hash=$(echo -n "$repo_root" | md5sum | cut -d' ' -f1 2>/dev/null || md5 -q -s "$repo_root")
    echo "$(get_spawn_dir)/${hash}.json"
}

# Load spawn state for current repo
load_spawn_state() {
    local state_file
    state_file=$(get_spawn_state_file "$REPO_DIR")

    if [ ! -f "$state_file" ]; then
        echo '{"spawned":[]}'
        return 0
    fi

    cat "$state_file"
}

# Save spawn state
save_spawn_state() {
    local state="$1"
    local spawn_dir
    spawn_dir=$(get_spawn_dir)
    local state_file
    state_file=$(get_spawn_state_file "$REPO_DIR")

    mkdir -p "$spawn_dir"
    echo "$state" | jq '.' > "$state_file"
}

# Register a spawned worktree
register_spawn() {
    local name="$1"
    local branch="$2"
    local context="$3"

    local state
    state=$(load_spawn_state)

    # Add to spawned list
    state=$(echo "$state" | jq --arg name "$name" \
        --arg branch "$branch" \
        --arg context "$context" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.spawned += [{name: $name, branch: $branch, context: $context, created: $ts}]')

    save_spawn_state "$state"
}

# Unregister a spawned worktree
unregister_spawn() {
    local name="$1"

    local state
    state=$(load_spawn_state)

    # Remove from spawned list
    state=$(echo "$state" | jq --arg name "$name" \
        '.spawned = [.spawned[] | select(.name != $name)]')

    save_spawn_state "$state"
}

# Check if a worktree was spawned
is_spawned() {
    local name="$1"
    local state
    state=$(load_spawn_state)

    local count
    count=$(echo "$state" | jq --arg name "$name" '[.spawned[] | select(.name == $name)] | length')

    [ "$count" -gt 0 ]
}

# Get list of all spawned worktree names
get_spawned_names() {
    local state
    state=$(load_spawn_state)
    echo "$state" | jq -r '.spawned[].name'
}

# Get spawn info for a specific worktree
get_spawn_info() {
    local name="$1"
    local state
    state=$(load_spawn_state)
    echo "$state" | jq --arg name "$name" '.spawned[] | select(.name == $name)'
}

# Write context file to worktree
write_context_file() {
    local worktree_path="$1"
    local context="$2"
    local context_file="$worktree_path/.claude-task"

    echo "$context" > "$context_file"

    # Ensure .claude-task is gitignored
    local gitignore="$worktree_path/.gitignore"
    if [ -f "$gitignore" ]; then
        if ! grep -q "^\.claude-task$" "$gitignore" 2>/dev/null; then
            echo ".claude-task" >> "$gitignore"
        fi
    else
        echo ".claude-task" > "$gitignore"
    fi

    echo "$context_file"
}

# --- Agent Context Loading ---

# Find the agents directory for the current repo
# Uses wt.toml agents.dir if set, otherwise defaults to ./agents
find_agents_dir() {
    local repo_root="${1:-$REPO_DIR}"

    # Check wt.toml for custom agents dir
    local agents_dir
    if has_wt_toml "$repo_root"; then
        agents_dir=$(get_wt_config "agents.dir" "$repo_root") || true
    fi

    # Default to ./agents
    agents_dir="${agents_dir:-./agents}"

    # Resolve relative to repo root
    if [[ "$agents_dir" == ./* ]]; then
        agents_dir="$repo_root/${agents_dir#./}"
    elif [[ "$agents_dir" != /* ]]; then
        agents_dir="$repo_root/$agents_dir"
    fi

    echo "$agents_dir"
}

# Check if agents INDEX.md exists
has_agents_index() {
    local agents_dir
    agents_dir=$(find_agents_dir "$1")

    [ -d "$agents_dir" ] && [ -f "$agents_dir/INDEX.md" ]
}

# Load all agents context markdown files
# Returns concatenated content from INDEX.md first, then other .md files
load_agents_context() {
    local repo_root="${1:-$REPO_DIR}"
    local agents_dir
    agents_dir=$(find_agents_dir "$repo_root")

    if ! has_agents_index "$repo_root"; then
        return 1
    fi

    local context=""

    # Read INDEX.md first
    if [ -f "$agents_dir/INDEX.md" ]; then
        context+="## Index\n\n"
        context+="$(cat "$agents_dir/INDEX.md")\n\n"
    fi

    # Read other markdown files (sorted alphabetically)
    for file in "$agents_dir"/*.md; do
        [ -f "$file" ] || continue
        local basename
        basename=$(basename "$file")
        if [ "$basename" != "INDEX.md" ]; then
            local name="${basename%.md}"
            context+="## $name\n\n"
            context+="$(cat "$file")\n\n"
        fi
    done

    echo -e "$context"
}

# Build the full spawn prompt with agents context and task context
build_spawn_prompt() {
    local task_context="$1"
    local repo_root="${2:-$REPO_DIR}"

    local prompt=""

    # Add agents context if available
    if has_agents_index "$repo_root"; then
        prompt+="# Agent Context\n\n"
        prompt+="$(load_agents_context "$repo_root")\n"
    fi

    # Add task context
    if [ -n "$task_context" ]; then
        prompt+="# Task\n\n"
        prompt+="$task_context"
    fi

    echo -e "$prompt"
}
