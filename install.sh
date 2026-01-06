#!/bin/bash

# wt Installer
# Install: curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash

set -e

REPO_URL="https://github.com/amiller68/worktree.git"
INSTALL_DIR="$HOME/.local/share/worktree"
BIN_DIR="$HOME/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Installing wt...${NC}"

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is required but not installed${NC}"
    exit 1
fi

# Create directories
mkdir -p "$BIN_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"

# Clone or update repo
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Existing installation found, updating...${NC}"
    cd "$INSTALL_DIR"
    git pull --ff-only origin main
else
    echo -e "${BLUE}Cloning repository...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Make executable
chmod +x "$INSTALL_DIR/_wt.sh"

# Create symlink for _wt
TARGET="$BIN_DIR/_wt"
if [ -L "$TARGET" ]; then
    rm "$TARGET"
elif [ -e "$TARGET" ]; then
    echo -e "${RED}Error: $TARGET exists and is not a symlink${NC}"
    exit 1
fi
ln -s "$INSTALL_DIR/_wt.sh" "$TARGET"

# Add source line to rc files
add_source_line() {
    local rc_file="$1"
    local shell_file="$2"
    local source_line="[ -f $shell_file ] && source $shell_file"

    if [ -f "$rc_file" ]; then
        if ! grep -q "worktree/shell/wt" "$rc_file" 2>/dev/null; then
            echo "" >> "$rc_file"
            echo "# wt - git worktree manager" >> "$rc_file"
            echo "$source_line" >> "$rc_file"
            echo -e "${GREEN}Added wt to $rc_file${NC}"
        else
            echo -e "${YELLOW}wt already in $rc_file${NC}"
        fi
    fi
}

add_source_line "$HOME/.bashrc" "$INSTALL_DIR/shell/wt.bash"
add_source_line "$HOME/.zshrc" "$INSTALL_DIR/shell/wt.zsh"

# Get version
VERSION="unknown"
if [ -f "$INSTALL_DIR/manifest.toml" ]; then
    VERSION=$(grep '^version' "$INSTALL_DIR/manifest.toml" | cut -d'"' -f2)
fi

echo ""
echo -e "${GREEN}Installed wt $VERSION${NC}"
echo -e "  ${BLUE}Location:${NC} $INSTALL_DIR"
echo -e "  ${BLUE}Command:${NC}  $TARGET"

# Check PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}Warning: $BIN_DIR is not in your PATH${NC}"
    echo "Add this to your shell profile:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo -e "${GREEN}Done! Restart your shell, then run 'wt' to get started.${NC}"
