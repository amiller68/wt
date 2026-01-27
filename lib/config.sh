#!/bin/bash

# wt.toml configuration file support
# Simple TOML parsing for bash

# Find wt.toml in the repo root
get_wt_toml() {
    local repo_root="$1"
    local toml_path="$repo_root/wt.toml"

    if [ -f "$toml_path" ]; then
        echo "$toml_path"
        return 0
    fi

    return 1
}

# Parse a simple value from wt.toml
# Handles: key = "value" or key = value or key = true/false
# Usage: parse_wt_toml_value "$toml_content" "section" "key"
parse_wt_toml_value() {
    local content="$1"
    local section="$2"
    local key="$3"

    local in_section=false
    local current_section=""

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Check for section header [section] or [section.subsection]
        if [[ "$line" =~ ^\[([a-zA-Z0-9._-]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # If we're in the right section, look for the key
        if [ "$in_section" = true ]; then
            # Match key = value (with optional quotes)
            if [[ "$line" =~ ^[[:space:]]*"$key"[[:space:]]*=[[:space:]]*(.*) ]]; then
                local value="${BASH_REMATCH[1]}"
                # Remove quotes if present
                value="${value#\"}"
                value="${value%\"}"
                # Remove leading/trailing whitespace
                value="${value#"${value%%[![:space:]]*}"}"
                value="${value%"${value##*[![:space:]]}"}"
                echo "$value"
                return 0
            fi
        fi
    done <<< "$content"

    return 1
}

# Parse an array from wt.toml
# Handles: key = ["value1", "value2"] (single line only)
# Usage: parse_wt_toml_array "$toml_content" "section" "key"
parse_wt_toml_array() {
    local content="$1"
    local section="$2"
    local key="$3"

    local in_section=false
    local current_section=""

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Check for section header
        if [[ "$line" =~ ^\[([a-zA-Z0-9._-]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            if [[ "$current_section" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # If we're in the right section, look for the key
        if [ "$in_section" = true ]; then
            # Match key = [...]
            if [[ "$line" =~ ^[[:space:]]*"$key"[[:space:]]*=[[:space:]]*\[(.*)\] ]]; then
                local array_content="${BASH_REMATCH[1]}"
                # Parse comma-separated values
                echo "$array_content" | tr ',' '\n' | while read -r item; do
                    # Remove quotes and whitespace
                    item="${item#"${item%%[![:space:]]*}"}"
                    item="${item%"${item##*[![:space:]]}"}"
                    item="${item#\"}"
                    item="${item%\"}"
                    [ -n "$item" ] && echo "$item"
                done
                return 0
            fi
        fi
    done <<< "$content"

    return 1
}

# Get a config value from wt.toml
# Usage: get_wt_config "section.key"
# Example: get_wt_config "spawn.auto"
get_wt_config() {
    local key_path="$1"
    local repo_root="${2:-$REPO_DIR}"

    local toml_path
    toml_path=$(get_wt_toml "$repo_root") || return 1

    local content
    content=$(cat "$toml_path")

    # Split key_path into section and key
    local section="${key_path%.*}"
    local key="${key_path##*.}"

    # If no dot in path, assume it's a top-level key
    if [ "$section" = "$key" ]; then
        section=""
    fi

    parse_wt_toml_value "$content" "$section" "$key"
}

# Get an array config value from wt.toml
# Usage: get_wt_config_array "section.key"
get_wt_config_array() {
    local key_path="$1"
    local repo_root="${2:-$REPO_DIR}"

    local toml_path
    toml_path=$(get_wt_toml "$repo_root") || return 1

    local content
    content=$(cat "$toml_path")

    # Split key_path into section and key
    local section="${key_path%.*}"
    local key="${key_path##*.}"

    parse_wt_toml_array "$content" "$section" "$key"
}

# Check if wt.toml exists for a repo
has_wt_toml() {
    local repo_root="${1:-$REPO_DIR}"
    [ -f "$repo_root/wt.toml" ]
}
