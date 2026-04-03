#!/usr/bin/env bash
# tests/test_validate_spec.sh
# TDD test suite for validate_spec.py and comparator_spec.yaml
# Phase 1: RED — all tests must fail before implementation.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() {
    echo "  PASS: $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
    ERRORS+=("$1")
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$PROJECT_ROOT/scripts/validate_spec.py"
SPEC="$PROJECT_ROOT/specs/comparator_spec.yaml"
TMPDIR_TEST="$(mktemp -d)"

# ---------------------------------------------------------------------------
# Test 1: Valid spec file → exit code 0
# ---------------------------------------------------------------------------
echo ""
echo "Test 1: valid spec → exit 0"
if python3 "$VALIDATOR" "$SPEC" > /dev/null 2>&1; then
    pass "validate_spec.py exits 0 on valid YAML"
else
    fail "validate_spec.py should exit 0 on valid YAML (exit=$?)"
fi

# ---------------------------------------------------------------------------
# Test 2: Spec missing 'units' field → exit non-zero, output contains param name
# ---------------------------------------------------------------------------
echo ""
echo "Test 2: spec missing 'units' → exit non-zero, output has param name"

INVALID_SPEC="$TMPDIR_TEST/invalid_missing_units.yaml"
cat > "$INVALID_SPEC" << 'EOF'
parameters:
  - name: t_prop_hl
    description: Propagation delay high-to-low
    min: null
    typ: 10
    max: 50
    condition: "VDD=1.8V"
    measurement_method: "50% crossing"
    testbench: tb/tb_tprop.sp
EOF

OUTPUT=$(python3 "$VALIDATOR" "$INVALID_SPEC" 2>&1 || true)
EXIT_CODE=0
python3 "$VALIDATOR" "$INVALID_SPEC" > /dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
    pass "validate_spec.py exits non-zero on YAML missing 'units'"
else
    fail "validate_spec.py should exit non-zero on YAML missing 'units' (exited 0)"
fi

if echo "$OUTPUT" | grep -q "t_prop_hl"; then
    pass "output contains parameter name 't_prop_hl' on missing-units error"
else
    fail "output should contain parameter name 't_prop_hl' but got: $OUTPUT"
fi

# ---------------------------------------------------------------------------
# Test 3: Nonexistent file → exit non-zero
# ---------------------------------------------------------------------------
echo ""
echo "Test 3: nonexistent file → exit non-zero"
EXIT_CODE=0
python3 "$VALIDATOR" "$TMPDIR_TEST/does_not_exist.yaml" > /dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
    pass "validate_spec.py exits non-zero on nonexistent file"
else
    fail "validate_spec.py should exit non-zero on nonexistent file"
fi

# ---------------------------------------------------------------------------
# Test 4: specs/comparator_spec.yaml exists and has all 7 expected parameters
# ---------------------------------------------------------------------------
echo ""
echo "Test 4: specs/comparator_spec.yaml exists with all 7 parameter names"

EXPECTED_PARAMS=(t_prop_hl t_prop_lh VOS VHYST Idd VOH VOL)

if [ -f "$SPEC" ]; then
    pass "specs/comparator_spec.yaml exists"
    for param in "${EXPECTED_PARAMS[@]}"; do
        if grep -q "name: $param" "$SPEC"; then
            pass "parameter '$param' present in comparator_spec.yaml"
        else
            fail "parameter '$param' missing from comparator_spec.yaml"
        fi
    done
else
    fail "specs/comparator_spec.yaml does not exist"
    for param in "${EXPECTED_PARAMS[@]}"; do
        fail "parameter '$param' cannot be checked (file missing)"
    done
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -rf "$TMPDIR_TEST"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "Failed tests:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
    echo "========================================"
    exit 1
else
    echo "All tests passed."
    echo "========================================"
    exit 0
fi
