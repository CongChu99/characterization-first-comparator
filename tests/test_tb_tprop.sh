#!/usr/bin/env bash
# tests/test_tb_tprop.sh
# TDD test suite for tb/tb_tprop.sp
# Task: characterization-first-comparator-3be.5
# Tests structural and content requirements before running ngspice.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB="$PROJECT_ROOT/tb/tb_tprop.sp"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_tb_tprop.sh ==="
echo ""

# [1] File exists
echo "[1] tb/tb_tprop.sp exists"
if [[ -f "$TB" ]]; then pass "tb/tb_tprop.sp exists"
else fail "tb/tb_tprop.sp does not exist"; fi

# [2] DUT instantiation
echo "[2] Comparator DUT instantiated (Xdut or Xcomp)"
if [[ -f "$TB" ]] && grep -qiE '^[[:space:]]*X(dut|comp)[[:space:]]' "$TB"; then
  pass "DUT instantiation found"
else
  fail "No DUT (Xdut/Xcomp) instantiation found in testbench"
fi

# [3] .include for netlist
echo "[3] .include for comparator netlist"
if [[ -f "$TB" ]] && grep -qi '\.include.*comparator\.spice' "$TB"; then
  pass ".include comparator.spice found"
else
  fail ".include comparator.spice not found"
fi

# [4] Corner parameterization (.param CORNER VDD TEMP)
echo "[4] Corner parameters declared (.param CORNER VDD TEMP)"
if [[ -f "$TB" ]]; then
  MISSING_PARAMS=()
  for P in CORNER VDD TEMP; do
    grep -qi "\.param.*${P}" "$TB" || MISSING_PARAMS+=("$P")
  done
  if [[ ${#MISSING_PARAMS[@]} -eq 0 ]]; then pass "All corner params found: CORNER VDD TEMP"
  else fail "Missing .param declarations: ${MISSING_PARAMS[*]}"; fi
else
  fail "Cannot check params — file missing"
fi

# [5] .meas for t_prop_hl
echo "[5] .meas t_prop_hl declared"
if [[ -f "$TB" ]] && grep -qi '\.meas.*t_prop_hl' "$TB"; then
  pass ".meas t_prop_hl found"
else
  fail ".meas t_prop_hl not found"
fi

# [6] .meas for t_prop_lh
echo "[6] .meas t_prop_lh declared"
if [[ -f "$TB" ]] && grep -qi '\.meas.*t_prop_lh' "$TB"; then
  pass ".meas t_prop_lh found"
else
  fail ".meas t_prop_lh not found"
fi

# [7] .tran transient analysis
echo "[7] .tran analysis declared"
if [[ -f "$TB" ]] && grep -qi '\.tran' "$TB"; then
  pass ".tran found"
else
  fail ".tran not found in testbench"
fi

# [8] Load capacitor CL=10fF or parameterized
echo "[8] Load capacitor (CL) present"
if [[ -f "$TB" ]] && grep -qiE '(CL|C_load|Cload|C[[:space:]]out)' "$TB"; then
  pass "Load capacitor found"
else
  fail "Load capacitor CL not found"
fi

# [9] .end statement
echo "[9] .end present"
if [[ -f "$TB" ]] && grep -qi '^\s*\.end\s*$' "$TB"; then
  pass ".end found"
else
  fail ".end not found in testbench"
fi

# [10] results/raw dir reference for output
echo "[10] results/ output path referenced (writeraw or .raw)"
if [[ -f "$TB" ]] && grep -qiE '(results/|writeraw|\.raw)' "$TB"; then
  pass "results/ output path referenced"
else
  fail "No results/ or writeraw reference found"
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
