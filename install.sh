#!/bin/bash

# Worktree Installer
# Install: curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash

set -e

REPO_URL="https://github.com/amiller68/worktree.git"
INSTALL_DIR="$HOME/.local/share/worktree"
BIN_DIR="$HOME/.local/bin"
COMMAND_NAME="worktree"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Installing worktree...${NC}"

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
chmod +x "$INSTALL_DIR/worktree.sh"

# Create symlink
TARGET="$BIN_DIR/$COMMAND_NAME"
if [ -L "$TARGET" ]; then
    rm "$TARGET"
elif [ -e "$TARGET" ]; then
    echo -e "${RED}Error: $TARGET exists and is not a symlink${NC}"
    exit 1
fi

ln -s "$INSTALL_DIR/worktree.sh" "$TARGET"

# Get version
VERSION="unknown"
if [ -f "$INSTALL_DIR/manifest.toml" ]; then
    VERSION=$(grep '^version' "$INSTALL_DIR/manifest.toml" | cut -d'"' -f2)
fi

echo -e "${GREEN}Installed worktree $VERSION${NC}"
echo -e "  ${BLUE}Location:${NC} $INSTALL_DIR"
echo -e "  ${BLUE}Command:${NC}  $TARGET"

# Check PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}Warning: $BIN_DIR is not in your PATH${NC}"
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo ""
echo -e "${GREEN}Done! Run 'worktree --help' to get started.${NC}"
