#!/usr/bin/env bash
# tests/test_validate_corners.sh
# TDD tests for validate_corners.sh (task characterization-first-comparator-3be.4)
# Phase 1: RED — all tests must fail before implementation.
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
# Test 1: script exits non-zero when PDK_ROOT is not set
# ---------------------------------------------------------------------------
section "Test 1: validate_corners.sh exits non-zero when PDK_ROOT is unset"

SCRIPT="$PROJECT_ROOT/scripts/validate_corners.sh"

unset PDK_ROOT 2>/dev/null || true

if [ ! -f "$SCRIPT" ]; then
    fail "scripts/validate_corners.sh does not exist — cannot test PDK_ROOT=unset behavior"
else
    OUTPUT=$(bash "$SCRIPT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ]; then
        pass "validate_corners.sh exits non-zero when PDK_ROOT is unset (exit=$EXIT_CODE)"
    else
        fail "validate_corners.sh should exit non-zero when PDK_ROOT is unset, but exited 0"
    fi
fi

# ---------------------------------------------------------------------------
# Test 2: script exits non-zero when PDK_ROOT points to a non-existent directory
# ---------------------------------------------------------------------------
section "Test 2: validate_corners.sh exits non-zero when PDK_ROOT is a non-existent directory"

export PDK_ROOT="/tmp/this_pdk_does_not_exist_$$"

if [ ! -f "$SCRIPT" ]; then
    fail "scripts/validate_corners.sh does not exist — cannot test PDK_ROOT=missing behavior"
else
    OUTPUT=$(bash "$SCRIPT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ]; then
        pass "validate_corners.sh exits non-zero when PDK_ROOT points to non-existent dir (exit=$EXIT_CODE)"
    else
        fail "validate_corners.sh should exit non-zero when PDK_ROOT is a missing directory, but exited 0"
    fi

    # Also verify both attempted paths are printed in output
    if echo "$OUTPUT" | grep -q "libs.ref"; then
        pass "output mentions at least one attempted PDK path (libs.ref)"
    else
        fail "output should mention attempted PDK paths but got: $OUTPUT"
    fi
fi

unset PDK_ROOT

# ---------------------------------------------------------------------------
# Test 3: scripts/validate_corners.sh exists and is executable
# ---------------------------------------------------------------------------
section "Test 3: scripts/validate_corners.sh exists and is executable"

if [ -f "$SCRIPT" ]; then
    pass "scripts/validate_corners.sh exists"
else
    fail "scripts/validate_corners.sh does not exist"
fi

if [ -x "$SCRIPT" ]; then
    pass "scripts/validate_corners.sh is executable"
else
    fail "scripts/validate_corners.sh is not executable"
fi

# ---------------------------------------------------------------------------
# Test 4: scripts/corner_check.sp exists
# ---------------------------------------------------------------------------
section "Test 4: scripts/corner_check.sp exists"

NETLIST="$PROJECT_ROOT/scripts/corner_check.sp"

if [ -f "$NETLIST" ]; then
    pass "scripts/corner_check.sp exists"
else
    fail "scripts/corner_check.sp does not exist"
fi

# Verify it has essential SPICE content
if [ -f "$NETLIST" ]; then
    if grep -q "\.lib" "$NETLIST"; then
        pass "corner_check.sp contains .lib directive"
    else
        fail "corner_check.sp should contain a .lib directive"
    fi

    if grep -q "\.op" "$NETLIST"; then
        pass "corner_check.sp contains .op (DC operating point) directive"
    else
        fail "corner_check.sp should contain .op directive"
    fi

    if grep -q "sky130_fd_pr__pfet_01v8\|sky130_fd_pr__nfet_01v8" "$NETLIST"; then
        pass "corner_check.sp references SKY130 device models"
    else
        fail "corner_check.sp should reference SKY130 NMOS/PMOS device models"
    fi
fi

# ---------------------------------------------------------------------------
# Test 5: Makefile validate-corners target calls the script
# ---------------------------------------------------------------------------
section "Test 5: Makefile validate-corners target invokes validate_corners.sh"

MAKEFILE="$PROJECT_ROOT/Makefile"

if [ ! -f "$MAKEFILE" ]; then
    fail "Makefile does not exist"
else
    if grep -q "validate_corners.sh" "$MAKEFILE"; then
        pass "Makefile validate-corners target references validate_corners.sh"
    else
        fail "Makefile validate-corners target does not call scripts/validate_corners.sh"
    fi
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
