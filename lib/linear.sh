#!/bin/bash

# Linear MCP integration helpers for wt epic command
# Uses claude CLI with Linear MCP to fetch epic data

# Fetch epic and sub-issues from Linear via claude CLI with Linear MCP
# Returns JSON with epic data and sub-issues
fetch_epic_data() {
    local epic_id="$1"

    # Use claude CLI to fetch Linear data via MCP
    # The prompt instructs claude to output structured JSON
    local prompt="Use the Linear MCP to get issue $epic_id with includeRelations=true. Then get all sub-issues (children) of this issue. Output ONLY valid JSON in this exact format, no other text:
{
  \"epic\": {
    \"id\": \"issue-uuid\",
    \"identifier\": \"$epic_id\",
    \"title\": \"epic title\",
    \"description\": \"epic description\",
    \"state\": \"state name\"
  },
  \"tasks\": [
    {
      \"id\": \"sub-issue-uuid\",
      \"identifier\": \"LIN-XXX\",
      \"title\": \"sub-issue title\",
      \"description\": \"sub-issue description\",
      \"state\": \"state name\",
      \"blockedBy\": [\"LIN-YYY\"],
      \"blocks\": [\"LIN-ZZZ\"]
    }
  ]
}"

    # Run claude with print mode
    # Note: stderr is shown so user can see/approve Linear MCP tool permissions
    echo -e "${YELLOW}  Running claude to fetch Linear data (you may need to approve tool use)...${NC}" >&2
    local result
    result=$(claude --print --max-turns 5 "$prompt")
    local exit_code=$?

    if [ $exit_code -ne 0 ] || [ -z "$result" ]; then
        echo -e "${RED}Error: Failed to fetch data from Linear (exit code: $exit_code)${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}  Linear data fetched successfully${NC}" >&2

    # Extract JSON from the response (claude may include surrounding text)
    # Look for the JSON object between { and }
    local json
    json=$(echo "$result" | sed -n '/{/,/^}/p' | head -n -0)

    # Validate it's proper JSON
    if ! echo "$json" | jq -e . >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid JSON response from Linear MCP${NC}" >&2
        echo "Raw response: $result" >&2
        return 1
    fi

    echo "$json"
}

# Get just the epic info
get_epic_info() {
    local epic_data="$1"
    echo "$epic_data" | jq -r '.epic'
}

# Get all tasks from epic data
get_tasks() {
    local epic_data="$1"
    echo "$epic_data" | jq -r '.tasks'
}

# Get tasks that are not blocked (can start immediately)
get_unblocked_tasks() {
    local epic_data="$1"
    echo "$epic_data" | jq -r '.tasks | map(select(.blockedBy == null or .blockedBy == []))'
}

# Get tasks blocked by a specific task ID
get_tasks_blocked_by() {
    local epic_data="$1"
    local task_id="$2"
    echo "$epic_data" | jq -r --arg id "$task_id" '.tasks | map(select(.blockedBy != null and (.blockedBy | contains([$id]))))'
}

# Check if a task is blocked
is_task_blocked() {
    local epic_data="$1"
    local task_id="$2"
    local blockers
    blockers=$(echo "$epic_data" | jq -r --arg id "$task_id" '.tasks[] | select(.identifier == $id) | .blockedBy // []')

    if [ "$blockers" = "[]" ] || [ -z "$blockers" ]; then
        return 1  # Not blocked
    fi
    return 0  # Blocked
}

# Update Linear issue status (e.g., mark as In Progress or Done)
update_linear_status() {
    local issue_id="$1"
    local status="$2"

    local prompt="Use the Linear MCP to update issue $issue_id and set its state to \"$status\". Confirm with a simple 'done' message."

    echo -e "${BLUE}  Updating Linear status for $issue_id...${NC}" >&2
    claude --print --max-turns 3 "$prompt" >/dev/null 2>&1 || true
}

# Create a comment on a Linear issue
add_linear_comment() {
    local issue_id="$1"
    local comment="$2"

    local prompt="Use the Linear MCP to create a comment on issue $issue_id with body: \"$comment\""

    claude --print --max-turns 3 "$prompt" >/dev/null 2>&1
}
