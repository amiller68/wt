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
    state_file=$(get_spawn_state_file "$TOPLEVEL_DIR")

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
    state_file=$(get_spawn_state_file "$TOPLEVEL_DIR")

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

