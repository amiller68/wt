#!/bin/bash

# Epic orchestration logic for wt epic command

# Get the epics state directory
get_epics_dir() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wt"
    echo "$config_dir/epics"
}

# Get path to epic state file
get_epic_state_file() {
    local epic_id="$1"
    echo "$(get_epics_dir)/${epic_id}.json"
}

# Check if epic state exists
epic_state_exists() {
    local epic_id="$1"
    local state_file=$(get_epic_state_file "$epic_id")
    [ -f "$state_file" ]
}

# Load epic state from file
load_epic_state() {
    local epic_id="$1"
    local state_file=$(get_epic_state_file "$epic_id")

    if [ ! -f "$state_file" ]; then
        return 1
    fi

    cat "$state_file"
}

# Save epic state to file
save_epic_state() {
    local epic_id="$1"
    local state="$2"
    local epics_dir=$(get_epics_dir)
    local state_file=$(get_epic_state_file "$epic_id")

    mkdir -p "$epics_dir"

    # Update lastUpdated timestamp
    state=$(echo "$state" | jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.lastUpdated = $ts')

    echo "$state" | jq '.' > "$state_file"
}

# Create initial epic state
create_epic_state() {
    local epic_id="$1"
    local integration_branch="$2"
    local tasks_json="$3"  # JSON array of tasks

    local state=$(jq -n \
        --arg epicId "$epic_id" \
        --arg integrationBranch "$integration_branch" \
        --arg tmuxSession "wt-epic-${epic_id}" \
        --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg lastUpdated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson tasks "$tasks_json" \
        '{
            epicId: $epicId,
            integrationBranch: $integrationBranch,
            tmuxSession: $tmuxSession,
            tasks: $tasks,
            created: $created,
            lastUpdated: $lastUpdated
        }')

    save_epic_state "$epic_id" "$state"
    echo "$state"
}

# Get task from state by ID
get_task_state() {
    local state="$1"
    local task_id="$2"
    echo "$state" | jq -r --arg id "$task_id" '.tasks[] | select(.issueId == $id or .identifier == $id)'
}

# Update task status in state
update_task_status() {
    local epic_id="$1"
    local task_id="$2"
    local new_status="$3"  # pending, in_progress, completed, blocked

    local state=$(load_epic_state "$epic_id")
    if [ -z "$state" ]; then
        return 1
    fi

    state=$(echo "$state" | jq --arg id "$task_id" --arg status "$new_status" \
        '(.tasks[] | select(.issueId == $id or .identifier == $id)).status = $status')

    save_epic_state "$epic_id" "$state"
}

# Set task pane ID
set_task_pane() {
    local epic_id="$1"
    local task_id="$2"
    local pane_id="$3"

    local state=$(load_epic_state "$epic_id")
    if [ -z "$state" ]; then
        return 1
    fi

    state=$(echo "$state" | jq --arg id "$task_id" --arg pane "$pane_id" \
        '(.tasks[] | select(.issueId == $id or .identifier == $id)).paneId = $pane')

    save_epic_state "$epic_id" "$state"
}

# Get all tasks with a specific status
get_tasks_by_status() {
    local state="$1"
    local status="$2"
    echo "$state" | jq -r --arg status "$status" '[.tasks[] | select(.status == $status)]'
}

# Check if all blockers for a task are completed
are_blockers_complete() {
    local state="$1"
    local task_id="$2"

    local task=$(get_task_state "$state" "$task_id")
    local blockers=$(echo "$task" | jq -r '.blockedBy // []')

    # If no blockers, return true
    if [ "$blockers" = "[]" ] || [ "$blockers" = "null" ] || [ -z "$blockers" ]; then
        return 0
    fi

    # Check each blocker
    for blocker in $(echo "$blockers" | jq -r '.[]'); do
        local blocker_state=$(get_task_state "$state" "$blocker")
        local blocker_status=$(echo "$blocker_state" | jq -r '.status')
        if [ "$blocker_status" != "completed" ]; then
            return 1  # Found incomplete blocker
        fi
    done

    return 0  # All blockers complete
}

# Get tasks that are now unblocked (blockers completed)
get_newly_unblocked_tasks() {
    local state="$1"

    local blocked_tasks=$(get_tasks_by_status "$state" "blocked")
    local result="[]"

    for task in $(echo "$blocked_tasks" | jq -c '.[]'); do
        local task_id=$(echo "$task" | jq -r '.identifier // .issueId')
        if are_blockers_complete "$state" "$task_id"; then
            result=$(echo "$result" | jq --argjson task "$task" '. + [$task]')
        fi
    done

    echo "$result"
}

# Delete epic state file
delete_epic_state() {
    local epic_id="$1"
    local state_file=$(get_epic_state_file "$epic_id")

    if [ -f "$state_file" ]; then
        rm "$state_file"
    fi
}

# Generate context file for a task
generate_task_context() {
    local task="$1"  # JSON task object
    local integration_branch="$2"
    local worktree_path="$3"

    local identifier=$(echo "$task" | jq -r '.identifier')
    local title=$(echo "$task" | jq -r '.title')
    local description=$(echo "$task" | jq -r '.description // "No description provided."')
    local blocked_by=$(echo "$task" | jq -r '.blockedBy // [] | join(", ")')
    local blocks=$(echo "$task" | jq -r '.blocks // [] | join(", ")')

    local context_file="$worktree_path/.claude-context"

    cat > "$context_file" << EOF
# Task: $identifier - $title

## Linear Issue
$description

## Dependencies
EOF

    if [ -n "$blocked_by" ] && [ "$blocked_by" != "" ]; then
        echo "- Blocked by: $blocked_by" >> "$context_file"
    else
        echo "- Blocked by: (none - this task is independent)" >> "$context_file"
    fi

    if [ -n "$blocks" ] && [ "$blocks" != "" ]; then
        echo "- Blocks: $blocks" >> "$context_file"
    fi

    cat >> "$context_file" << EOF

## Integration
- Your branch: $identifier
- Merge target: $integration_branch
- When done, run: wt epic complete $identifier

## Instructions
Work on implementing the task described above. When you're finished:
1. Commit your changes
2. Run: wt epic complete $identifier
This will merge your work into the integration branch and unlock any dependent tasks.
EOF

    echo "$context_file"
}

# Print epic status in a formatted way
print_epic_status() {
    local state="$1"

    local epic_id=$(echo "$state" | jq -r '.epicId')
    local integration_branch=$(echo "$state" | jq -r '.integrationBranch')
    local tmux_session=$(echo "$state" | jq -r '.tmuxSession')
    local created=$(echo "$state" | jq -r '.created')

    echo -e "${BLUE}Epic:${NC} $epic_id"
    echo -e "${BLUE}Integration Branch:${NC} $integration_branch"
    echo -e "${BLUE}tmux Session:${NC} $tmux_session"
    echo -e "${BLUE}Created:${NC} $created"
    echo ""
    echo -e "${BLUE}Tasks:${NC}"

    local tasks=$(echo "$state" | jq -c '.tasks[]')
    while IFS= read -r task; do
        local id=$(echo "$task" | jq -r '.identifier // .issueId')
        local title=$(echo "$task" | jq -r '.title')
        local status=$(echo "$task" | jq -r '.status')
        local blocked_by=$(echo "$task" | jq -r '.blockedBy // [] | join(", ")')

        local status_color
        case "$status" in
            completed) status_color="${GREEN}" ;;
            in_progress) status_color="${BLUE}" ;;
            blocked) status_color="${YELLOW}" ;;
            *) status_color="${NC}" ;;
        esac

        echo -e "  ${status_color}[$status]${NC} $id: $title"
        if [ -n "$blocked_by" ] && [ "$blocked_by" != "" ]; then
            echo -e "         ${YELLOW}blocked by: $blocked_by${NC}"
        fi
    done <<< "$tasks"
}
