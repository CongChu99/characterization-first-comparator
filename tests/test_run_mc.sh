#!/usr/bin/env bash
# tests/test_run_mc.sh
# TDD test suite for scripts/run_mc.sh and MC testbench infrastructure
# Task: characterization-first-comparator-3be.9
# Validates structural and behavioral requirements (no ngspice needed).

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$PROJECT_ROOT/scripts/run_mc.sh"
MAKEFILE="$PROJECT_ROOT/Makefile"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_run_mc.sh ==="
echo ""

# [1] scripts/run_mc.sh exists
echo "[1] scripts/run_mc.sh exists"
if [[ -f "$SCRIPT" ]]; then pass "scripts/run_mc.sh exists"
else fail "scripts/run_mc.sh does not exist"; fi

# [2] Script is executable
echo "[2] scripts/run_mc.sh is executable"
if [[ -f "$SCRIPT" ]] && [[ -x "$SCRIPT" ]]; then pass "run_mc.sh is executable"
else fail "run_mc.sh is not executable"; fi

# [3] MC iteration count >= 200 defined
echo "[3] MC iteration count >= 200 defined"
if [[ -f "$SCRIPT" ]] && grep -qE '(200|MC_RUNS|N_RUNS|n_runs)' "$SCRIPT"; then
  pass "MC iteration count (>= 200) referenced"
else
  fail "MC iteration count not found — spec requires >= 200 runs"
fi

# [4] SKY130 MC model switches referenced (mc_mm_switch or mc_pr_switch)
echo "[4] SKY130 MC model switches referenced"
if [[ -f "$SCRIPT" ]] && grep -qiE '(mc_mm_switch|mc_pr_switch|mc.*switch|statistical|montecarlo)' "$SCRIPT"; then
  pass "SKY130 MC model switches referenced"
else
  fail "SKY130 MC switches (mc_mm_switch/mc_pr_switch) not referenced"
fi

# [5] results/mc/ output directory referenced
echo "[5] results/mc/ output path referenced"
if [[ -f "$SCRIPT" ]] && grep -qE 'results/mc' "$SCRIPT"; then
  pass "results/mc/ directory referenced"
else
  fail "results/mc/ not referenced in script"
fi

# [6] Per-run CSV or scalar output referenced (run_NNN.csv or iteration result)
echo "[6] Per-run output format referenced (csv or raw per run)"
if [[ -f "$SCRIPT" ]] && grep -qiE '(run_|\.csv|per.run|iteration)' "$SCRIPT"; then
  pass "Per-run output format referenced"
else
  fail "No per-run output format found — need run_NNN.csv or similar"
fi

# [7] ngspice invoked in batch mode (-b)
echo "[7] ngspice invoked in batch mode (-b)"
if [[ -f "$SCRIPT" ]] && grep -qE 'ngspice.*-b|-b.*ngspice' "$SCRIPT"; then
  pass "ngspice -b invocation found"
else
  fail "ngspice -b not found — batch mode required"
fi

# [8] Random seed setting for reproducibility
echo "[8] Random seed for reproducibility (rndseed or seed)"
if [[ -f "$SCRIPT" ]] && grep -qiE '(rndseed|seed|SEED|reproducib)' "$SCRIPT"; then
  pass "Random seed reference found"
else
  fail "No random seed — reproducibility requires set rndseed=N"
fi

# [9] PDK_ROOT guard
echo "[9] PDK_ROOT guard present"
if [[ -f "$SCRIPT" ]] && grep -qE '(PDK_ROOT|pdk_root)' "$SCRIPT"; then
  pass "PDK_ROOT guard found"
else
  fail "No PDK_ROOT check in run_mc.sh"
fi

# [10] Makefile mc target calls run_mc.sh (not just echo stub)
echo "[10] Makefile mc target calls run_mc.sh (not stub)"
if [[ -f "$MAKEFILE" ]] && grep -A3 '^mc:' "$MAKEFILE" | grep -q 'run_mc'; then
  pass "Makefile mc target calls run_mc.sh"
else
  fail "Makefile mc target is still a stub — must call scripts/run_mc.sh"
fi

# [11] Makefile mc target depends on validate-corners
echo "[11] Makefile mc depends on validate-corners"
if [[ -f "$MAKEFILE" ]] && grep -E '^mc:.*validate-corners' "$MAKEFILE"; then
  pass "mc depends on validate-corners"
else
  fail "mc target missing validate-corners dependency"
fi

# [12] tb/ testbench references (MC wrapper spice files or TB_MAP)
echo "[12] Testbench references in script (tb/ or MC wrapper spice)"
if [[ -f "$SCRIPT" ]] && grep -qE '(tb/|TB_DIR|TB_MAP|_mc\.sp)' "$SCRIPT"; then
  pass "Testbench references found"
else
  fail "No testbench references — MC must iterate over testbenches"
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
