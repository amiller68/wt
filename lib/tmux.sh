#!/bin/bash

# tmux session management helpers for wt epic command

# Check if tmux is installed
check_tmux() {
    if ! command -v tmux &>/dev/null; then
        echo -e "${RED}Error: tmux is required for wt epic. Install it with your package manager.${NC}" >&2
        return 1
    fi
}

# Create a new tmux session for an epic
# Returns session name
create_epic_session() {
    local epic_id="$1"
    local session_name="wt-epic-${epic_id}"

    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "${YELLOW}Session '$session_name' already exists${NC}" >&2
        echo "$session_name"
        return 0
    fi

    # Create new detached session
    tmux new-session -d -s "$session_name" -n "overview"

    echo "$session_name"
}

# Add a new pane/window for a task
# Returns the pane ID
add_task_pane() {
    local session_name="$1"
    local task_id="$2"
    local worktree_path="$3"
    local context_file="$4"

    # Create a new window for the task
    local window_name="${task_id}"
    tmux new-window -t "$session_name" -n "$window_name"

    # Send commands to the new window
    # 1. cd to worktree
    tmux send-keys -t "$session_name:$window_name" "cd \"$worktree_path\"" Enter

    # 2. Launch claude with the context
    if [ -n "$context_file" ] && [ -f "$context_file" ]; then
        tmux send-keys -t "$session_name:$window_name" "claude < \"$context_file\"" Enter
    else
        tmux send-keys -t "$session_name:$window_name" "claude" Enter
    fi

    # Get the pane ID
    local pane_id
    pane_id=$(tmux display-message -t "$session_name:$window_name" -p '#{pane_id}')

    echo "$pane_id"
}

# Add a task pane that doesn't auto-launch claude (for dependent tasks)
add_waiting_pane() {
    local session_name="$1"
    local task_id="$2"
    local worktree_path="$3"
    local blocked_by="$4"

    # Create a new window for the task
    local window_name="${task_id}-blocked"
    tmux new-window -t "$session_name" -n "$window_name"

    # cd to worktree and show waiting message
    tmux send-keys -t "$session_name:$window_name" "cd \"$worktree_path\"" Enter
    tmux send-keys -t "$session_name:$window_name" "echo 'Waiting for: $blocked_by'" Enter
    tmux send-keys -t "$session_name:$window_name" "echo 'Run: wt epic complete <task-id> when blocker is done'" Enter

    # Get the pane ID
    local pane_id
    pane_id=$(tmux display-message -t "$session_name:$window_name" -p '#{pane_id}')

    echo "$pane_id"
}

# Activate a waiting pane (start claude)
activate_task_pane() {
    local session_name="$1"
    local task_id="$2"
    local context_file="$3"

    # Find the window for this task
    local window_name="${task_id}-blocked"

    # Rename window to remove -blocked suffix
    tmux rename-window -t "$session_name:$window_name" "$task_id" 2>/dev/null || true

    # Launch claude
    if [ -n "$context_file" ] && [ -f "$context_file" ]; then
        tmux send-keys -t "$session_name:$task_id" "claude < \"$context_file\"" Enter
    else
        tmux send-keys -t "$session_name:$task_id" "claude" Enter
    fi
}

# Attach to an epic session
attach_epic_session() {
    local epic_id="$1"
    local session_name="wt-epic-${epic_id}"

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "${RED}Error: No session found for epic '$epic_id'${NC}" >&2
        return 1
    fi

    tmux attach -t "$session_name"
}

# Kill an epic session
kill_epic_session() {
    local epic_id="$1"
    local session_name="wt-epic-${epic_id}"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux kill-session -t "$session_name"
        echo -e "${GREEN}Session '$session_name' terminated${NC}" >&2
    fi
}

# Check if session exists
session_exists() {
    local epic_id="$1"
    local session_name="wt-epic-${epic_id}"
    tmux has-session -t "$session_name" 2>/dev/null
}

# List windows in a session
list_session_windows() {
    local epic_id="$1"
    local session_name="wt-epic-${epic_id}"

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        return 1
    fi

    tmux list-windows -t "$session_name" -F "#{window_name}: #{window_active}"
}
