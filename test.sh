#!/bin/bash
# Test runner for wt

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

# Use local version - add script dir to PATH and source local shell config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"
export WORKTREE_INSTALL_DIR="$SCRIPT_DIR"
ln -sf "$SCRIPT_DIR/_wt.sh" "$SCRIPT_DIR/_wt"
source "$SCRIPT_DIR/shell/wt.bash"

# Setup test repo with origin/main (default base branch)
TEST_DIR=$(mktemp -d)
TEST_CONFIG_DIR=$(mktemp -d)
export XDG_CONFIG_HOME="$TEST_CONFIG_DIR"
cd "$TEST_DIR"
git init -q -b main
git commit --allow-empty -m "init" -q
git remote add origin "$TEST_DIR"
git fetch -q origin

# Assert helpers
assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}: $msg"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((FAIL++))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="$2"
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}: $msg (dir does not exist: $dir)"
        ((FAIL++))
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local msg="$2"
    if [[ ! -d "$dir" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}: $msg (dir exists: $dir)"
        ((FAIL++))
    fi
}

echo "=== wt tests ==="
echo "Test dir: $TEST_DIR"
echo ""

# Run test modules
source "$SCRIPT_DIR/tests/test_basic.sh"
source "$SCRIPT_DIR/tests/test_nested.sh"
source "$SCRIPT_DIR/tests/test_config.sh"
source "$SCRIPT_DIR/tests/test_exit.sh"
source "$SCRIPT_DIR/tests/test_hooks.sh"
source "$SCRIPT_DIR/tests/test_open_all.sh"
source "$SCRIPT_DIR/tests/test_spawn.sh"

# Cleanup
echo ""
echo "--- Cleanup ---"
rm -rf "$TEST_DIR"
rm -rf "$TEST_CONFIG_DIR"
echo "Removed $TEST_DIR"
echo "Removed $TEST_CONFIG_DIR"

echo ""
echo "=== Results ==="
echo -e "${GREEN}Passed${NC}: $PASS"
echo -e "${RED}Failed${NC}: $FAIL"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
