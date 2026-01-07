#!/bin/bash
# Setup local development environment for wt
# Usage: source ./dev.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Create symlink for _wt
ln -sf "$SCRIPT_DIR/_wt.sh" "$SCRIPT_DIR/_wt"

# Prepend to PATH so local version takes precedence
export PATH="$SCRIPT_DIR:$PATH"

# Source shell integration (detect shell)
if [[ -n "$ZSH_VERSION" ]]; then
    source "$SCRIPT_DIR/shell/wt.zsh"
elif [[ -n "$BASH_VERSION" ]]; then
    source "$SCRIPT_DIR/shell/wt.bash"
fi

echo "Using local wt from: $SCRIPT_DIR"
echo "Run 'wt version' to verify"
