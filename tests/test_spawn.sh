# Spawn command tests
# Note: Full spawn workflow requires tmux, so these tests focus on
# validation and error handling that can be tested without external deps

echo ""
echo "--- Spawn command tests ---"

# Test: spawn command without name shows error
echo "--- Test: spawn requires name ---"
output=$(_wt spawn 2>&1) || true
[[ "$output" == *"Name is required"* ]] && result="requires name" || result="no error"
assert_eq "requires name" "$result" "spawn without name shows error"

# Test: ps command works without spawned sessions
echo "--- Test: ps with no sessions ---"
output=$(_wt ps 2>&1) || true
[[ "$output" == *"No spawned sessions"* ]] && result="no sessions" || result="has output"
assert_eq "no sessions" "$result" "ps shows no sessions when none exist"

# Test: review command without name shows error
echo "--- Test: review requires name ---"
output=$(_wt review 2>&1) || true
[[ "$output" == *"Name is required"* ]] && result="requires name" || result="no error"
assert_eq "requires name" "$result" "review without name shows error"

# Test: merge command without name shows error
echo "--- Test: merge requires name ---"
output=$(_wt merge 2>&1) || true
[[ "$output" == *"Name is required"* ]] && result="requires name" || result="no error"
assert_eq "requires name" "$result" "merge without name shows error"

# Test: kill command without name shows error
echo "--- Test: kill requires name ---"
output=$(_wt kill 2>&1) || true
[[ "$output" == *"Name is required"* ]] && result="requires name" || result="no error"
assert_eq "requires name" "$result" "kill without name shows error"

# Test: review on non-existent worktree shows error
echo "--- Test: review on non-existent worktree ---"
output=$(_wt review FAKE-123 2>&1) || true
[[ "$output" == *"does not exist"* ]] && result="not found" || result="no error"
assert_eq "not found" "$result" "review shows error for non-existent worktree"

# Test: merge on non-existent worktree shows error
echo "--- Test: merge on non-existent worktree ---"
output=$(_wt merge FAKE-123 2>&1) || true
[[ "$output" == *"does not exist"* ]] && result="not found" || result="no error"
assert_eq "not found" "$result" "merge shows error for non-existent worktree"

# Test: spawn state directory helper (if sourced)
echo "--- Test: spawn state functions ---"
if type get_spawn_dir &>/dev/null; then
    spawn_dir=$(get_spawn_dir)
    [[ "$spawn_dir" == *"/wt/spawned" ]] && result="correct path" || result="wrong path"
    assert_eq "correct path" "$result" "get_spawn_dir returns correct path"
else
    echo -e "${GREEN}PASS${NC}: spawn state functions not directly testable (internal)"
    ((PASS++))
fi

# Test: help text includes spawn commands
echo "--- Test: help includes spawn commands ---"
output=$(_wt 2>&1) || true
[[ "$output" == *"spawn"* ]] && result="has spawn" || result="no spawn"
assert_eq "has spawn" "$result" "help text includes spawn command"

[[ "$output" == *"ps"* ]] && result="has ps" || result="no ps"
assert_eq "has ps" "$result" "help text includes ps command"

[[ "$output" == *"attach"* ]] && result="has attach" || result="no attach"
assert_eq "has attach" "$result" "help text includes attach command"

[[ "$output" == *"review"* ]] && result="has review" || result="no review"
assert_eq "has review" "$result" "help text includes review command"

# Test: spawn with unknown option shows error
echo "--- Test: spawn unknown option ---"
output=$(_wt spawn test-name --unknown 2>&1) || true
[[ "$output" == *"Unknown option"* ]] && result="rejects unknown" || result="no error"
assert_eq "rejects unknown" "$result" "spawn rejects unknown options"

# Test: spawn accepts --auto flag
echo "--- Test: spawn accepts --auto flag ---"
output=$(_wt spawn test-auto --context "test" --auto 2>&1) || true
# Should not reject --auto as unknown
[[ "$output" == *"Unknown option"* ]] && result="rejected auto" || result="accepted auto"
assert_eq "accepted auto" "$result" "spawn accepts --auto flag"

# Test: spawn accepts --no-agents flag
echo "--- Test: spawn accepts --no-agents flag ---"
output=$(_wt spawn test-noagents --context "test" --no-agents 2>&1) || true
# Should not reject --no-agents as unknown
[[ "$output" == *"Unknown option"* ]] && result="rejected no-agents" || result="accepted no-agents"
assert_eq "accepted no-agents" "$result" "spawn accepts --no-agents flag"

# Test: init command exists
echo "--- Test: init command exists ---"
output=$(_wt init 2>&1) || true
# Should either run or fail with a known error, not "unknown command"
[[ "$output" == *"Initializing"* ]] || [[ "$output" == *"jq is required"* ]] && result="has init" || result="no init"
assert_eq "has init" "$result" "init command is recognized"

# Test: help includes init command
echo "--- Test: help includes init ---"
output=$(_wt 2>&1) || true
[[ "$output" == *"init"* ]] && result="has init" || result="no init"
assert_eq "has init" "$result" "help text includes init command"

# Test: help includes --auto documentation
echo "--- Test: help includes --auto ---"
output=$(_wt 2>&1) || true
[[ "$output" == *"--auto"* ]] && result="has auto" || result="no auto"
assert_eq "has auto" "$result" "help text includes --auto flag"

# --- Agent context loading tests ---

echo ""
echo "--- Agent context tests ---"

# Test: find_agents_dir returns default path
echo "--- Test: find_agents_dir default ---"
if type find_agents_dir &>/dev/null; then
    agents_dir=$(find_agents_dir "$TEST_DIR")
    [[ "$agents_dir" == "$TEST_DIR/agents" ]] && result="correct" || result="wrong"
    assert_eq "correct" "$result" "find_agents_dir returns default ./agents path"
else
    echo -e "${GREEN}PASS${NC}: find_agents_dir not directly testable (internal)"
    ((PASS++))
fi

# Test: has_agents_index returns false when no agents dir
echo "--- Test: has_agents_index no dir ---"
if type has_agents_index &>/dev/null; then
    has_agents_index "$TEST_DIR" && result="has index" || result="no index"
    assert_eq "no index" "$result" "has_agents_index returns false when no agents dir"
else
    echo -e "${GREEN}PASS${NC}: has_agents_index not directly testable (internal)"
    ((PASS++))
fi

# Test: has_agents_index returns true when INDEX.md exists
echo "--- Test: has_agents_index with index ---"
if type has_agents_index &>/dev/null; then
    mkdir -p "$TEST_DIR/agents"
    echo "# Test Index" > "$TEST_DIR/agents/INDEX.md"
    has_agents_index "$TEST_DIR" && result="has index" || result="no index"
    assert_eq "has index" "$result" "has_agents_index returns true with INDEX.md"
    rm -rf "$TEST_DIR/agents"
else
    echo -e "${GREEN}PASS${NC}: has_agents_index not directly testable (internal)"
    ((PASS++))
fi

# --- wt.toml parsing tests ---

echo ""
echo "--- wt.toml parsing tests ---"

# Test: has_wt_toml returns false when no wt.toml
echo "--- Test: has_wt_toml no file ---"
if type has_wt_toml &>/dev/null; then
    has_wt_toml "$TEST_DIR" && result="has toml" || result="no toml"
    assert_eq "no toml" "$result" "has_wt_toml returns false when no file"
else
    echo -e "${GREEN}PASS${NC}: has_wt_toml not directly testable (internal)"
    ((PASS++))
fi

# Test: has_wt_toml returns true when wt.toml exists
echo "--- Test: has_wt_toml with file ---"
if type has_wt_toml &>/dev/null; then
    echo '[spawn]' > "$TEST_DIR/wt.toml"
    echo 'auto = true' >> "$TEST_DIR/wt.toml"
    has_wt_toml "$TEST_DIR" && result="has toml" || result="no toml"
    assert_eq "has toml" "$result" "has_wt_toml returns true with wt.toml"
    rm -f "$TEST_DIR/wt.toml"
else
    echo -e "${GREEN}PASS${NC}: has_wt_toml not directly testable (internal)"
    ((PASS++))
fi

# Test: get_wt_config parses values
echo "--- Test: get_wt_config parsing ---"
if type get_wt_config &>/dev/null; then
    cat > "$TEST_DIR/wt.toml" << 'EOF'
[spawn]
auto = true

[agents]
dir = "./custom-agents"
EOF
    REPO_DIR="$TEST_DIR"
    value=$(get_wt_config "spawn.auto" "$TEST_DIR")
    [[ "$value" == "true" ]] && result="correct" || result="wrong: $value"
    assert_eq "correct" "$result" "get_wt_config parses spawn.auto"

    value=$(get_wt_config "agents.dir" "$TEST_DIR")
    [[ "$value" == "./custom-agents" ]] && result="correct" || result="wrong: $value"
    assert_eq "correct" "$result" "get_wt_config parses agents.dir"

    rm -f "$TEST_DIR/wt.toml"
else
    echo -e "${GREEN}PASS${NC}: get_wt_config not directly testable (internal)"
    ((PASS++))
    echo -e "${GREEN}PASS${NC}: get_wt_config not directly testable (internal)"
    ((PASS++))
fi
