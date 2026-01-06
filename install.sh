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

# Bash function + completion
BASH_FUNC='# wt - git worktree manager
wt() {
    if [[ "$1" == "open" || "$1" == "-o" ]]; then
        eval "$(_wt "$@")"
    else
        _wt "$@"
    fi
}
_wt_completions() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD-1]}
    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "create list remove open cleanup update version -o" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case $prev in
            open|remove)
                local repo=$(git rev-parse --show-toplevel 2>/dev/null)
                if [[ -d "$repo/.worktrees" ]]; then
                    COMPREPLY=($(compgen -W "$(ls "$repo/.worktrees" 2>/dev/null)" -- "$cur"))
                fi
                ;;
            -o) COMPREPLY=($(compgen -W "create" -- "$cur")) ;;
        esac
    fi
}
complete -F _wt_completions wt'

# Zsh function + completion
ZSH_FUNC='# wt - git worktree manager
wt() {
    if [[ "$1" == "open" || "$1" == "-o" ]]; then
        eval "$(_wt "$@")"
    else
        _wt "$@"
    fi
}
_wt_completions() {
    local commands="create list remove open cleanup update version"
    if (( CURRENT == 2 )); then
        _alternative "args:command:(create list remove open cleanup update version -o)"
    elif (( CURRENT == 3 )); then
        case ${words[2]} in
            open|remove)
                local repo=$(git rev-parse --show-toplevel 2>/dev/null)
                if [[ -d "$repo/.worktrees" ]]; then
                    local wts=($(ls "$repo/.worktrees" 2>/dev/null))
                    _describe "worktree" wts
                fi
                ;;
            -o) _alternative "args:command:(create)" ;;
        esac
    fi
}
compdef _wt_completions wt'

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

# Add shell function to rc files
add_shell_func() {
    local rc_file="$1"
    local func_code="$2"
    if [ -f "$rc_file" ]; then
        if ! grep -q "^wt()" "$rc_file" 2>/dev/null; then
            echo "" >> "$rc_file"
            echo "$func_code" >> "$rc_file"
            echo -e "${GREEN}Added wt function to $rc_file${NC}"
        else
            echo -e "${YELLOW}wt function already in $rc_file${NC}"
        fi
    fi
}

add_shell_func "$HOME/.bashrc" "$BASH_FUNC"
add_shell_func "$HOME/.zshrc" "$ZSH_FUNC"

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
