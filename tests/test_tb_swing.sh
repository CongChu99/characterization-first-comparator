#!/usr/bin/env bash
# tests/test_tb_swing.sh
# TDD test suite for tb/tb_swing.sp
# Task: characterization-first-comparator-3be.7
# Tests structural and content requirements before running ngspice.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB="$PROJECT_ROOT/tb/tb_swing.sp"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_tb_swing.sh ==="
echo ""

# [1] File exists
echo "[1] tb/tb_swing.sp exists"
if [[ -f "$TB" ]]; then pass "tb/tb_swing.sp exists"
else fail "tb/tb_swing.sp does not exist"; fi

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

# [5] DC analysis (.op or .dc) declared
echo "[5] .op or .dc analysis declared"
if [[ -f "$TB" ]] && grep -qiE '^\s*\.(op|dc)\b' "$TB"; then
  pass ".op or .dc analysis found"
else
  fail ".op/.dc analysis not found in testbench"
fi

# [6] .meas for VOH (output high voltage)
echo "[6] .meas VOH declared"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(VOH|voh|V_OH)' "$TB"; then
  pass ".meas VOH found"
else
  fail ".meas VOH not found — output high voltage measurement missing"
fi

# [7] .meas for VOL (output low voltage)
echo "[7] .meas VOL declared"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(VOL|vol|V_OL)' "$TB"; then
  pass ".meas VOL found"
else
  fail ".meas VOL not found — output low voltage measurement missing"
fi

# [8] INP driven to VDD (VOH condition: INP >> INN)
echo "[8] INP=VDD condition present (for VOH)"
if [[ -f "$TB" ]] && grep -qiE '(INP|Vinp|inp).*DC.*\{VDD\}|Vinp.*VDD[^/]' "$TB"; then
  pass "INP=VDD stimulus found"
else
  # Alternative: may use .dc sweep or separate DC points
  if [[ -f "$TB" ]] && grep -qiE '(VDD|vdd)\s*\}?\s*(;|$|\*)' "$TB"; then
    pass "VDD reference found in stimulus"
  else
    fail "No INP=VDD condition found for VOH measurement"
  fi
fi

# [9] Load resistor on output (to avoid floating output)
echo "[9] Load resistor (Rload or RL) on OUT node"
if [[ -f "$TB" ]] && grep -qiE '^[[:space:]]*(R[Ll]|R_load|Rload)[[:space:]].*out' "$TB"; then
  pass "Load resistor found"
else
  # Also accept capacitor or explicit comment about load
  if [[ -f "$TB" ]] && grep -qiE '(Rload|RL|1Meg|1MEG|1[mM][eE][gG])' "$TB"; then
    pass "Load element (1MΩ or similar) found"
  else
    fail "No load resistor (Rload/RL 1MΩ) found — floating output may cause incorrect VOH/VOL"
  fi
fi

# [10] .end statement
echo "[10] .end present"
if [[ -f "$TB" ]] && grep -qi '^\s*\.end\s*$' "$TB"; then
  pass ".end found"
else
  fail ".end not found in testbench"
fi

# [11] results/ output path or .control write section
echo "[11] results/ output path or .control section"
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
