#!/usr/bin/env bash
# tests/test_run_corners.sh
# TDD test suite for scripts/run_corners.sh and Makefile corners target
# Task: characterization-first-comparator-3be.8
# Validates structural and behavioral requirements (no ngspice needed).

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$PROJECT_ROOT/scripts/run_corners.sh"
MAKEFILE="$PROJECT_ROOT/Makefile"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_run_corners.sh ==="
echo ""

# [1] scripts/run_corners.sh exists
echo "[1] scripts/run_corners.sh exists"
if [[ -f "$SCRIPT" ]]; then pass "scripts/run_corners.sh exists"
else fail "scripts/run_corners.sh does not exist"; fi

# [2] Script is executable
echo "[2] scripts/run_corners.sh is executable"
if [[ -f "$SCRIPT" ]] && [[ -x "$SCRIPT" ]]; then pass "run_corners.sh is executable"
else fail "run_corners.sh is not executable (missing +x)"; fi

# [3] Corner matrix: all 5 process corners defined
echo "[3] All 5 process corners defined (tt ff ss fs sf)"
if [[ -f "$SCRIPT" ]]; then
  MISSING_CORNERS=()
  for C in tt ff ss fs sf; do
    grep -q "$C" "$SCRIPT" || MISSING_CORNERS+=("$C")
  done
  if [[ ${#MISSING_CORNERS[@]} -eq 0 ]]; then pass "All 5 corners present: tt ff ss fs sf"
  else fail "Missing corners in script: ${MISSING_CORNERS[*]}"; fi
else
  fail "Cannot check corners — file missing"
fi

# [4] Temperature sweep: -40, 27, 125 defined
echo "[4] Temperature sweep points defined (-40 27 125)"
if [[ -f "$SCRIPT" ]]; then
  MISSING_TEMPS=()
  for T in "\-40" "27" "125"; do
    grep -qE "$T" "$SCRIPT" || MISSING_TEMPS+=("$T")
  done
  if [[ ${#MISSING_TEMPS[@]} -eq 0 ]]; then pass "All 3 temperatures present: -40 27 125"
  else fail "Missing temperatures: ${MISSING_TEMPS[*]}"; fi
else
  fail "Cannot check temps — file missing"
fi

# [5] VDD sweep: 1.62, 1.80, 1.98 defined
echo "[5] VDD sweep points defined (1.62 1.80 1.98)"
if [[ -f "$SCRIPT" ]]; then
  MISSING_VDDS=()
  for V in "1.62" "1.80" "1.98"; do
    grep -qF "$V" "$SCRIPT" || MISSING_VDDS+=("$V")
  done
  if [[ ${#MISSING_VDDS[@]} -eq 0 ]]; then pass "All 3 VDD values present: 1.62 1.80 1.98"
  else fail "Missing VDD values: ${MISSING_VDDS[*]}"; fi
else
  fail "Cannot check VDDs — file missing"
fi

# [6] ngspice invocation with -b (batch mode)
echo "[6] ngspice invoked in batch mode (-b flag)"
if [[ -f "$SCRIPT" ]] && grep -qE 'ngspice.*-b|-b.*ngspice' "$SCRIPT"; then
  pass "ngspice -b invocation found"
else
  fail "ngspice -b not found — batch mode required"
fi

# [7] results/corners/ output directory referenced
echo "[7] results/corners/ output path referenced"
if [[ -f "$SCRIPT" ]] && grep -qE 'results/corners' "$SCRIPT"; then
  pass "results/corners/ directory referenced"
else
  fail "results/corners/ not referenced in script"
fi

# [8] failures.log handling present
echo "[8] failures.log referenced for error logging"
if [[ -f "$SCRIPT" ]] && grep -qi 'failures.log' "$SCRIPT"; then
  pass "failures.log referenced"
else
  fail "failures.log not referenced — partial failures must be logged"
fi

# [9] Corner tag format encoded in output path (corner_vdd_temp or similar)
echo "[9] Corner-tagged output path (e.g., tt_1800mV_27C)"
if [[ -f "$SCRIPT" ]] && grep -qiE '(corner_tag|CORNER_TAG|\$\{corner\}|\$corner)' "$SCRIPT"; then
  pass "Corner tag variable found in output naming"
else
  fail "No corner tag pattern found — output must encode corner/vdd/temp"
fi

# [10] Testbench directory (tb/) referenced via TB_DIR or literal
echo "[10] tb/ directory referenced"
if [[ -f "$SCRIPT" ]] && grep -qE '(tb/|TB_DIR|TB_MAP)' "$SCRIPT"; then
  pass "tb/ testbench directory referenced"
else
  fail "tb/ not referenced — script must iterate over testbenches"
fi

# [11] Makefile has real corners target (not just echo stub)
echo "[11] Makefile corners target calls run_corners.sh (not just echo stub)"
if [[ -f "$MAKEFILE" ]] && grep -A3 '^corners:' "$MAKEFILE" | grep -q 'run_corners'; then
  pass "Makefile corners target calls run_corners.sh"
else
  fail "Makefile corners target is still a stub — must call scripts/run_corners.sh"
fi

# [12] Makefile corners target depends on validate-corners
echo "[12] Makefile corners depends on validate-corners"
if [[ -f "$MAKEFILE" ]] && grep -E '^corners:.*validate-corners' "$MAKEFILE"; then
  pass "corners depends on validate-corners"
else
  fail "corners target missing validate-corners dependency"
fi

# [13] Script handles ngspice exit code (failure detection)
echo "[13] Script checks ngspice exit code or uses error handling"
if [[ -f "$SCRIPT" ]] && grep -qE '(\$\?|pipefail|set -e|if.*ngspice|ngspice.*&&|\|\|)' "$SCRIPT"; then
  pass "Exit code / error handling found"
else
  fail "No exit code handling for ngspice failures"
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
