#!/usr/bin/env bash
# tests/test_tb_vhyst.sh
# TDD test suite for tb/tb_vhyst.sp
# Task: characterization-first-comparator-3be.6
# Tests structural and content requirements before running ngspice.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB="$PROJECT_ROOT/tb/tb_vhyst.sp"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_tb_vhyst.sh ==="
echo ""

# [1] File exists
echo "[1] tb/tb_vhyst.sp exists"
if [[ -f "$TB" ]]; then pass "tb/tb_vhyst.sp exists"
else fail "tb/tb_vhyst.sp does not exist"; fi

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

# [5] DC sweep declared
echo "[5] .dc sweep analysis declared"
if [[ -f "$TB" ]] && grep -qiE '^\s*\.dc\b' "$TB"; then
  pass ".dc sweep found"
else
  fail ".dc analysis not found — hysteresis requires bidirectional DC sweep"
fi

# [6] .meas for VIN_rise or rising threshold crossing
echo "[6] .meas for rising threshold (VIN_rise or vth_rise)"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(rise|VIN_r|vth_r|thresh_r|vin_rise)' "$TB"; then
  pass ".meas VIN_rise found"
else
  fail ".meas VIN_rise not found — need rising threshold for hysteresis calculation"
fi

# [7] .meas for VIN_fall or falling threshold crossing
echo "[7] .meas for falling threshold (VIN_fall or vth_fall)"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(fall|VIN_f|vth_f|thresh_f|vin_fall)' "$TB"; then
  pass ".meas VIN_fall found"
else
  fail ".meas VIN_fall not found — need falling threshold for hysteresis calculation"
fi

# [8] .meas for VHYST (hysteresis = VIN_fall - VIN_rise)
echo "[8] .meas VHYST declared"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(VHYST|vhyst|V_HYST|hysteresis)' "$TB"; then
  pass ".meas VHYST found"
else
  fail ".meas VHYST not found — hysteresis measurement missing"
fi

# [9] .end statement
echo "[9] .end present"
if [[ -f "$TB" ]] && grep -qi '^\s*\.end\s*$' "$TB"; then
  pass ".end found"
else
  fail ".end not found in testbench"
fi

# [10] results/ output path or .control section
echo "[10] results/ output path or .control section"
if [[ -f "$TB" ]] && grep -qiE '(results/|\.control|set rawfile)' "$TB"; then
  pass "results/ output path or .control section found"
else
  fail "No results/ or .control section found"
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
