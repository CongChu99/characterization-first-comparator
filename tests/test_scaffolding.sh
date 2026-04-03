#!/usr/bin/env bash
# tests/test_scaffolding.sh
# TDD tests for project scaffolding (task characterization-first-comparator-3be.1)
# Run from any directory; uses absolute paths relative to the project root.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
FAILURES=()

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
pass() {
    echo "  PASS: $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
    FAILURES+=("$1")
}

section() {
    echo ""
    echo "=== $1 ==="
}

# ---------------------------------------------------------------------------
# Test 1: make characterize without PDK_ROOT exits non-zero
# ---------------------------------------------------------------------------
section "Test 1: make characterize WITHOUT PDK_ROOT set"

# Ensure PDK_ROOT is not set
unset PDK_ROOT 2>/dev/null || true

make_output=$(cd "$PROJECT_ROOT" && make characterize 2>&1) && make_exit=0 || make_exit=$?

if [ "$make_exit" -ne 0 ]; then
    pass "make characterize exits non-zero when PDK_ROOT is unset (exit=$make_exit)"
else
    fail "make characterize should exit non-zero when PDK_ROOT is unset, but exited 0"
fi

expected_msg="PDK_ROOT is not set"
if echo "$make_output" | grep -q "$expected_msg"; then
    pass "make characterize prints expected error message containing: '$expected_msg'"
else
    fail "make characterize did not print expected message '$expected_msg'. Got: $make_output"
fi

# ---------------------------------------------------------------------------
# Test 2: All required directories exist
# (Must run before make clean, which removes results/)
# ---------------------------------------------------------------------------
section "Test 2: All required directories exist"

REQUIRED_DIRS=(
    "specs"
    "schematic"
    "netlist"
    "tb"
    "scripts/extract"
    "scripts/report/templates"
    "results"
    "reports"
)

# Ensure results/ exists for this check (it may have been removed by a prior run)
mkdir -p "$PROJECT_ROOT/results"

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        pass "Directory exists: $dir"
    else
        fail "Directory missing: $dir"
    fi
done

# ---------------------------------------------------------------------------
# Test 3: make clean succeeds (even with empty/missing results/)
# ---------------------------------------------------------------------------
section "Test 3: make clean succeeds"

make_clean_output=$(cd "$PROJECT_ROOT" && make clean 2>&1) && make_clean_exit=0 || make_clean_exit=$?

if [ "$make_clean_exit" -eq 0 ]; then
    pass "make clean exits 0"
else
    fail "make clean exited non-zero (exit=$make_clean_exit). Output: $make_clean_output"
fi

# Verify reports/ directory still exists after clean
if [ -d "$PROJECT_ROOT/reports" ]; then
    pass "reports/ directory still exists after make clean"
else
    fail "reports/ directory was removed by make clean (it should be preserved)"
fi

# Verify results/ directory is removed after clean
if [ ! -d "$PROJECT_ROOT/results" ]; then
    pass "results/ directory does not exist after make clean"
else
    fail "results/ directory should have been removed by make clean"
fi

# Verify make clean also works when results/ is already absent
make_clean2_output=$(cd "$PROJECT_ROOT" && make clean 2>&1) && make_clean2_exit=0 || make_clean2_exit=$?

if [ "$make_clean2_exit" -eq 0 ]; then
    pass "make clean exits 0 even when results/ is already absent"
else
    fail "make clean exited non-zero when results/ was already absent (exit=$make_clean2_exit)"
fi

# ---------------------------------------------------------------------------
# Test 4: results/ is gitignored
# ---------------------------------------------------------------------------
section "Test 4: results/ is gitignored"

gitignore_file="$PROJECT_ROOT/.gitignore"
if [ -f "$gitignore_file" ]; then
    if grep -q "results/" "$gitignore_file" || grep -q "^results$" "$gitignore_file"; then
        pass ".gitignore contains results/"
    else
        fail ".gitignore does not contain results/ — results must be gitignored"
    fi
else
    fail ".gitignore file does not exist"
fi

# ---------------------------------------------------------------------------
# Test 5: requirements.txt exists and has expected packages
# ---------------------------------------------------------------------------
section "Test 5: requirements.txt exists with expected packages"

req_file="$PROJECT_ROOT/requirements.txt"
if [ -f "$req_file" ]; then
    pass "requirements.txt exists"
else
    fail "requirements.txt does not exist"
fi

for pkg in spicelib pandas jinja2 matplotlib; do
    if grep -qi "$pkg" "$req_file" 2>/dev/null; then
        pass "requirements.txt includes $pkg"
    else
        fail "requirements.txt missing $pkg"
    fi
done

# ---------------------------------------------------------------------------
# Test 6: Makefile exists
# ---------------------------------------------------------------------------
section "Test 6: Makefile exists"

if [ -f "$PROJECT_ROOT/Makefile" ]; then
    pass "Makefile exists"
else
    fail "Makefile does not exist"
fi

# ---------------------------------------------------------------------------
# Test 7: README.md exists
# ---------------------------------------------------------------------------
section "Test 7: README.md exists"

if [ -f "$PROJECT_ROOT/README.md" ]; then
    pass "README.md exists"
else
    fail "README.md does not exist"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED tests:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi

echo "ALL TESTS PASSED"
exit 0
