#!/bin/bash
# Simple tests for wt

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

# Use local version - add script dir to PATH and source local shell config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"
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

# Test: create worktree
echo "--- Test: create worktree ---"
_wt create test1 2>/dev/null
assert_dir_exists "$TEST_DIR/.worktrees/test1" "create worktree"
# .git in worktree is a file, not a dir
[[ -f "$TEST_DIR/.worktrees/test1/.git" ]] && echo -e "${GREEN}PASS${NC}: worktree has .git file" && ((PASS++)) || { echo -e "${RED}FAIL${NC}: worktree missing .git file"; ((FAIL++)); }

# Test: list worktrees
echo "--- Test: list worktrees ---"
output=$(_wt list 2>/dev/null)
assert_eq "test1" "$output" "list shows test1"

# Test: create with -o flag outputs cd command
echo "--- Test: create with -o outputs cd ---"
output=$(_wt create test2 -o 2>/dev/null)
[[ "$output" == *"cd "* ]] && result="contains cd" || result="no cd"
assert_eq "contains cd" "$result" "create -o outputs cd command"

# Test: open outputs cd command
echo "--- Test: open outputs cd ---"
output=$(_wt open test1 2>/dev/null)
# Handle macOS /var -> /private/var symlink
expected_path=$(cd "$TEST_DIR/.worktrees/test1" && pwd -P)
[[ "$output" == *"$expected_path"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "open outputs correct cd"

# Test: remove worktree
echo "--- Test: remove worktree ---"
_wt remove test1 2>/dev/null
assert_dir_not_exists "$TEST_DIR/.worktrees/test1" "remove deletes worktree"

# Test: list after remove
echo "--- Test: list after remove ---"
output=$(_wt list 2>/dev/null)
[[ "$output" != *"test1"* ]] && result="test1 gone" || result="test1 still there"
assert_eq "test1 gone" "$result" "list doesn't show removed worktree"

# Test: create -o with error should not leak color codes to stdout
echo "--- Test: create -o error no color leak ---"
# Create a worktree first
_wt create errortest 2>/dev/null
# Try to create same one with -o, capture stdout only
stdout_output=$(_wt create errortest -o 2>/dev/null) || true
# Check stdout doesn't contain escape sequences (color codes)
[[ "$stdout_output" != *$'\033'* ]] && result="clean" || result="has color codes"
assert_eq "clean" "$result" "create -o error has no color codes in stdout"
# Cleanup
_wt remove errortest 2>/dev/null

# Test: nested path create
echo "--- Test: nested path create ---"
_wt create feature/test/nested 2>/dev/null
assert_dir_exists "$TEST_DIR/.worktrees/feature/test/nested" "nested path created"

# Test: list shows nested path
echo "--- Test: list shows nested ---"
output=$(_wt list 2>/dev/null)
[[ "$output" == *"feature/test/nested"* ]] && result="found" || result="not found"
assert_eq "found" "$result" "list shows nested path"

# Test: regex remove
echo "--- Test: regex remove ---"
_wt create regex-test1 2>/dev/null
_wt create regex-test2 2>/dev/null
_wt remove 'regex-test*' 2>/dev/null
output=$(_wt list 2>/dev/null)
[[ "$output" != *"regex-test"* ]] && result="removed" || result="still exists"
assert_eq "removed" "$result" "regex remove works"

# Test: config - default base branch
echo "--- Test: config default ---"
output=$(_wt config 2>/dev/null)
[[ "$output" == *"origin/main"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "default base branch is origin/main"

# Test: config - set repo base branch
echo "--- Test: config set repo base ---"
_wt config base origin/develop 2>/dev/null
output=$(_wt config base 2>/dev/null)
assert_eq "origin/develop" "$output" "config base shows set value"

# Test: config - get_base_branch returns repo config
echo "--- Test: get_base_branch uses repo config ---"
output=$(_wt config 2>/dev/null)
[[ "$output" == *"origin/develop"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "effective base branch uses repo config"

# Test: config - unset repo base branch
echo "--- Test: config unset repo base ---"
_wt config base --unset 2>/dev/null
output=$(_wt config base 2>/dev/null)
[[ "$output" == *"No config set"* ]] && result="unset" || result="still set"
assert_eq "unset" "$result" "config base --unset works"

# Test: config - set global default
echo "--- Test: config set global default ---"
_wt config base --global origin/master 2>/dev/null
output=$(_wt config base --global 2>/dev/null)
assert_eq "origin/master" "$output" "global default shows set value"

# Test: config - global is used when no repo config
echo "--- Test: config global fallback ---"
output=$(_wt config 2>/dev/null)
[[ "$output" == *"origin/master"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "global default is used as fallback"

# Test: config - repo config takes precedence over global
echo "--- Test: config repo over global ---"
_wt config base origin/feature 2>/dev/null
output=$(_wt config 2>/dev/null)
[[ "$output" == *"Effective base branch"*"origin/feature"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "repo config takes precedence over global"

# Test: config --list
echo "--- Test: config --list ---"
output=$(_wt config --list 2>/dev/null)
[[ "$output" == *"[global]"* && "$output" == *"$TEST_DIR"* ]] && result="correct" || result="wrong"
assert_eq "correct" "$result" "config --list shows all entries"

# Test: config - unset global
echo "--- Test: config unset global ---"
_wt config base --global --unset 2>/dev/null
output=$(_wt config base --global 2>/dev/null)
[[ "$output" == *"No global default"* ]] && result="unset" || result="still set"
assert_eq "unset" "$result" "config base --global --unset works"

# Clean up repo config for next tests
_wt config base --unset 2>/dev/null

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
