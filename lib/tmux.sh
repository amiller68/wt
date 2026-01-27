#!/bin/bash

# tmux session management helpers for wt spawn command
# Uses a single session (wt-spawned) with each task as a window

SPAWN_SESSION="wt-spawned"

# Check if tmux is installed
check_tmux() {
    if ! command -v tmux &>/dev/null; then
        echo -e "${RED}Error: tmux is required for wt spawn. Install it with your package manager.${NC}" >&2
        return 1
    fi
}

# Ensure the spawn session exists, create if needed
ensure_spawn_session() {
    if ! tmux has-session -t "$SPAWN_SESSION" 2>/dev/null; then
        # Create new detached session with a placeholder window
        tmux new-session -d -s "$SPAWN_SESSION" -n "wt"
        # The placeholder window will be closed when first real window is added
    fi
    echo "$SPAWN_SESSION"
}

# Add a new window for a spawned task
# Launches claude in the worktree directory
# If auto_mode is true and prompt is provided, uses --dangerously-skip-permissions -p
spawn_window() {
    local name="$1"
    local worktree_path="$2"
    local context_file="$3"  # Optional .claude-task file
    local auto_mode="${4:-false}"
    local prompt="$5"  # Full prompt for auto mode

    ensure_spawn_session >/dev/null

    # Check if window already exists
    if tmux list-windows -t "$SPAWN_SESSION" -F '#{window_name}' 2>/dev/null | grep -q "^${name}$"; then
        echo -e "${YELLOW}Window '$name' already exists in session${NC}" >&2
        return 0
    fi

    # Create new window
    tmux new-window -t "$SPAWN_SESSION" -n "$name"

    # cd to worktree
    tmux send-keys -t "$SPAWN_SESSION:$name" "cd \"$worktree_path\"" Enter

    # Launch claude
    if [ "$auto_mode" = true ] && [ -n "$prompt" ]; then
        # Auto mode: write prompt to temp file to handle escaping
        local prompt_file="$worktree_path/.claude-spawn-prompt"
        echo "$prompt" > "$prompt_file"

        # Add prompt file to gitignore
        local gitignore="$worktree_path/.gitignore"
        if [ -f "$gitignore" ]; then
            if ! grep -q "^\.claude-spawn-prompt$" "$gitignore" 2>/dev/null; then
                echo ".claude-spawn-prompt" >> "$gitignore"
            fi
        fi

        # Launch claude with --dangerously-skip-permissions and prompt from file
        tmux send-keys -t "$SPAWN_SESSION:$name" "claude --dangerously-skip-permissions -p \"\$(cat '$prompt_file')\"" Enter
    else
        # Normal mode: just launch claude (context via .claude-task file)
        tmux send-keys -t "$SPAWN_SESSION:$name" "claude" Enter
    fi

    # Kill the placeholder window if it still exists
    tmux kill-window -t "$SPAWN_SESSION:wt" 2>/dev/null || true
}

# Kill a specific window
kill_window() {
    local name="$1"

    if ! tmux has-session -t "$SPAWN_SESSION" 2>/dev/null; then
        return 0
    fi

    # Kill the window
    tmux kill-window -t "$SPAWN_SESSION:$name" 2>/dev/null || true
}

# Attach to spawn session, optionally switch to specific window
attach_spawn() {
    local window_name="$1"  # Optional

    if ! tmux has-session -t "$SPAWN_SESSION" 2>/dev/null; then
        echo -e "${RED}Error: No spawn session exists. Use 'wt spawn' to create tasks first.${NC}" >&2
        return 1
    fi

    if [ -n "$window_name" ]; then
        # Switch to specific window before attaching
        tmux select-window -t "$SPAWN_SESSION:$window_name" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Window '$window_name' not found${NC}" >&2
        }
    fi

    tmux attach -t "$SPAWN_SESSION"
}

# Check if spawn session exists
spawn_session_exists() {
    tmux has-session -t "$SPAWN_SESSION" 2>/dev/null
}

# List all windows in spawn session
list_spawn_windows() {
    if ! tmux has-session -t "$SPAWN_SESSION" 2>/dev/null; then
        return 1
    fi

    tmux list-windows -t "$SPAWN_SESSION" -F '#{window_name}'
}

# Check if a window is running (has active process)
is_window_running() {
    local name="$1"

    if ! tmux has-session -t "$SPAWN_SESSION" 2>/dev/null; then
        return 1
    fi

    # Check if window exists
    if ! tmux list-windows -t "$SPAWN_SESSION" -F '#{window_name}' 2>/dev/null | grep -q "^${name}$"; then
        return 1
    fi

    # Check if pane has running command (not just shell)
    local pane_cmd
    pane_cmd=$(tmux display-message -t "$SPAWN_SESSION:$name" -p '#{pane_current_command}' 2>/dev/null)

    # If pane is running claude, it's active
    [[ "$pane_cmd" == "claude" ]] || [[ "$pane_cmd" == "node" ]]
}

# Get window status (running, exited)
get_window_status() {
    local name="$1"

    if ! tmux has-session -t "$SPAWN_SESSION" 2>/dev/null; then
        echo "no_session"
        return
    fi

    if ! tmux list-windows -t "$SPAWN_SESSION" -F '#{window_name}' 2>/dev/null | grep -q "^${name}$"; then
        echo "no_window"
        return
    fi

    if is_window_running "$name"; then
        echo "running"
    else
        echo "exited"
    fi
}
