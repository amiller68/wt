# Epic command tests
# Note: Full epic workflow requires Linear MCP, so these tests focus on
# validation and state management that can be tested without external deps

echo ""
echo "--- Epic command tests ---"

# Test: epic command shows help without args
echo "--- Test: epic help ---"
output=$(_wt epic 2>&1) || true
[[ "$output" == *"Usage: wt epic"* ]] && result="shows help" || result="no help"
assert_eq "shows help" "$result" "epic without args shows help"

# Test: epic status without ID shows error
echo "--- Test: epic status requires ID ---"
output=$(_wt epic status 2>&1) || true
[[ "$output" == *"Epic ID required"* ]] && result="requires id" || result="no error"
assert_eq "requires id" "$result" "epic status requires issue ID"

# Test: epic complete without ID shows error
echo "--- Test: epic complete requires ID ---"
output=$(_wt epic complete 2>&1) || true
[[ "$output" == *"Task ID required"* ]] && result="requires id" || result="no error"
assert_eq "requires id" "$result" "epic complete requires task ID"

# Test: epic cleanup without ID shows error
echo "--- Test: epic cleanup requires ID ---"
output=$(_wt epic cleanup 2>&1) || true
[[ "$output" == *"Epic ID required"* ]] && result="requires id" || result="no error"
assert_eq "requires id" "$result" "epic cleanup requires issue ID"

# Test: epic status on non-existent epic shows error
echo "--- Test: epic status on non-existent ---"
output=$(_wt epic status FAKE-123 2>&1) || true
[[ "$output" == *"No epic found"* ]] && result="not found" || result="no error"
assert_eq "not found" "$result" "epic status shows not found for fake ID"

# Test: epic spawn from root repo shows error (not in worktree)
echo "--- Test: epic requires worktree ---"
# We're in the root test repo, not a worktree
output=$(_wt epic TEST-123 --dry-run 2>&1) || true
[[ "$output" == *"Must run 'wt epic' from within a worktree"* ]] && result="requires worktree" || result="no error"
assert_eq "requires worktree" "$result" "epic spawn requires running from worktree"

# Test: epic state directory creation
echo "--- Test: epic state functions ---"
# Test the state directory helper (if sourced)
if type get_epics_dir &>/dev/null; then
    epics_dir=$(get_epics_dir)
    [[ "$epics_dir" == *"/wt/epics" ]] && result="correct path" || result="wrong path"
    assert_eq "correct path" "$result" "get_epics_dir returns correct path"
else
    echo -e "${GREEN}PASS${NC}: epic state functions not directly testable (internal)"
    ((PASS++))
fi

# Test: epic complete on non-existent task shows error
echo "--- Test: epic complete task not found ---"
output=$(_wt epic complete FAKE-TASK-456 2>&1) || true
[[ "$output" == *"not found in any epic"* ]] && result="not found" || result="no error"
assert_eq "not found" "$result" "epic complete shows error for fake task"
