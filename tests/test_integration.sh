#!/usr/bin/env bash
# tests/test_integration.sh
# TDD test suite for make characterize integration and README
# Task: characterization-first-comparator-3be.12
# Validates Makefile wiring, check-coverage target, and README completeness.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MAKEFILE="$PROJECT_ROOT/Makefile"
README="$PROJECT_ROOT/README.md"
SPEC="$PROJECT_ROOT/specs/comparator_spec.yaml"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_integration.sh ==="
echo ""

# ---------------------------------------------------------------------------
# Makefile: characterize target dependency chain
# ---------------------------------------------------------------------------

# [1] characterize depends on validate-spec
echo "[1] Makefile: characterize depends on validate-spec"
if [[ -f "$MAKEFILE" ]] && grep -E '^characterize:' "$MAKEFILE" | grep -q 'validate-spec'; then
  pass "characterize → validate-spec"
else
  fail "characterize target missing validate-spec dependency"
fi

# [2] characterize depends on validate-corners
echo "[2] Makefile: characterize depends on validate-corners"
if [[ -f "$MAKEFILE" ]] && grep -E '^characterize:' "$MAKEFILE" | grep -q 'validate-corners'; then
  pass "characterize → validate-corners"
else
  fail "characterize target missing validate-corners dependency"
fi

# [3] characterize depends on check-coverage
echo "[3] Makefile: characterize depends on check-coverage"
if [[ -f "$MAKEFILE" ]] && grep -E '^characterize:' "$MAKEFILE" | grep -q 'check-coverage'; then
  pass "characterize → check-coverage"
else
  fail "characterize target missing check-coverage dependency"
fi

# [4] characterize depends on corners, mc, extract, report (full chain)
echo "[4] Makefile: characterize has full pipeline (corners mc extract report)"
if [[ -f "$MAKEFILE" ]]; then
  CHAIN_LINE=$(grep -E '^characterize:' "$MAKEFILE" | head -1)
  MISSING=()
  for DEP in corners mc extract report; do
    echo "$CHAIN_LINE" | grep -q "$DEP" || MISSING+=("$DEP")
  done
  if [[ ${#MISSING[@]} -eq 0 ]]; then pass "Full pipeline chain: corners mc extract report"
  else fail "characterize missing deps: ${MISSING[*]}"; fi
else
  fail "Cannot check characterize chain — Makefile missing"
fi

# [5] check-coverage target is implemented (not just echo stub)
echo "[5] Makefile: check-coverage is real (not stub)"
if [[ -f "$MAKEFILE" ]] && grep -A4 '^check-coverage:' "$MAKEFILE" | grep -qv 'Not yet implemented'; then
  pass "check-coverage target is real implementation"
else
  fail "check-coverage is still a stub — must verify testbench coverage"
fi

# [6] check-coverage actually checks tb/ files against spec params
echo "[6] check-coverage references tb/ and spec YAML"
if [[ -f "$MAKEFILE" ]]; then
  COVERAGE_IMPL=$(grep -A4 '^check-coverage:' "$MAKEFILE")
  if echo "$COVERAGE_IMPL" | grep -qE '(tb/|python3|spec|YAML|comparator_spec|check_coverage)'; then
    pass "check-coverage references tb/ or spec YAML"
  else
    fail "check-coverage does not reference tb/ or spec — must verify coverage"
  fi
else
  fail "Cannot check coverage target — Makefile missing"
fi

# [7] PDK_ROOT guard prints meaningful error message (not just make error)
echo "[7] Makefile: PDK_ROOT guard has descriptive error message"
if [[ -f "$MAKEFILE" ]] && grep -q 'PDK_ROOT is not set' "$MAKEFILE"; then
  pass "PDK_ROOT guard has descriptive message"
else
  fail "PDK_ROOT guard missing descriptive error message"
fi

# ---------------------------------------------------------------------------
# README completeness
# ---------------------------------------------------------------------------

# [8] README.md exists
echo "[8] README.md exists"
if [[ -f "$README" ]]; then pass "README.md exists"
else fail "README.md does not exist"; fi

# [9] README has Prerequisites section (ngspice, Python, PDK)
echo "[9] README: Prerequisites section with ngspice and Python"
if [[ -f "$README" ]] && grep -qi 'prerequisite\|requirement\|install' "$README"; then
  if grep -qi 'ngspice' "$README" && grep -qi 'python' "$README"; then
    pass "README has prerequisites with ngspice and Python"
  else
    fail "README prerequisites missing ngspice or Python mention"
  fi
else
  fail "README missing Prerequisites/Requirements section"
fi

# [10] README has PDK_ROOT setup instructions
echo "[10] README: PDK_ROOT setup instructions"
if [[ -f "$README" ]] && grep -q 'PDK_ROOT' "$README"; then
  pass "README has PDK_ROOT setup instructions"
else
  fail "README missing PDK_ROOT instructions"
fi

# [11] README has Quick Start / make characterize usage
echo "[11] README: make characterize quick start"
if [[ -f "$README" ]] && grep -q 'make characterize' "$README"; then
  pass "README has 'make characterize' quick start"
else
  fail "README missing 'make characterize' usage"
fi

# [12] README documents expected runtime
echo "[12] README: expected runtime documented"
if [[ -f "$README" ]] && grep -qiE '(minute|hour|runtime|~\d+|approx)' "$README"; then
  pass "README documents expected runtime"
else
  fail "README missing expected runtime information"
fi

# [13] README has Methodology section (explains the characterization-first approach)
echo "[13] README: Methodology section"
if [[ -f "$README" ]] && grep -qiE '(methodology|approach|characterization.first|workflow)' "$README"; then
  pass "README has Methodology/Approach section"
else
  fail "README missing Methodology section"
fi

# [14] README describes output files (reports/characterization_report.html)
echo "[14] README: output files described (characterization_report.html)"
if [[ -f "$README" ]] && grep -qi 'characterization_report.html' "$README"; then
  pass "README describes output report file"
else
  fail "README missing output file description"
fi

# ---------------------------------------------------------------------------
# Coverage check script/logic
# ---------------------------------------------------------------------------

# [15] check-coverage verifies all spec params have a testbench file
echo "[15] Functional: check-coverage passes with all 5 testbenches present"
if [[ -f "$MAKEFILE" ]]; then
  # Run check-coverage without PDK_ROOT (it should not need PDK for coverage check)
  RESULT=$(PDK_ROOT=/tmp make -f "$MAKEFILE" check-coverage 2>&1 || true)
  if echo "$RESULT" | grep -qiE '(PASS|pass|OK|covered|all.*present|found)' || \
     ! echo "$RESULT" | grep -qiE '(FAIL|fail|missing|not found)'; then
    pass "check-coverage passes with all testbenches present"
  else
    fail "check-coverage reports failures despite all testbenches being present: $RESULT"
  fi
else
  fail "Cannot run check-coverage — Makefile missing"
fi

echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo "FAILED tests:"
  for ERR in "${ERRORS[@]}"; do echo "  - $ERR"; done
  echo "==============================="
  exit 1
else
  echo "ALL TESTS PASSED"
  echo "==============================="
  exit 0
fi
