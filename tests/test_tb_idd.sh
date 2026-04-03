#!/usr/bin/env bash
# tests/test_tb_idd.sh
# TDD test suite for tb/tb_idd.sp
# Task: characterization-first-comparator-3be.7
# Tests structural and content requirements before running ngspice.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB="$PROJECT_ROOT/tb/tb_idd.sp"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_tb_idd.sh ==="
echo ""

# [1] File exists
echo "[1] tb/tb_idd.sp exists"
if [[ -f "$TB" ]]; then pass "tb/tb_idd.sp exists"
else fail "tb/tb_idd.sp does not exist"; fi

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

# [5] DC operating point or DC analysis declared
echo "[5] .op or .dc analysis declared"
if [[ -f "$TB" ]] && grep -qiE '^\s*\.(op|dc)\b' "$TB"; then
  pass ".op or .dc analysis found"
else
  fail ".op/.dc analysis not found in testbench"
fi

# [6] Current measurement: .meas for Idd (supply current)
echo "[6] .meas Idd declared"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(idd|I_VDD|i_vdd|IDD)' "$TB"; then
  pass ".meas Idd found"
else
  fail ".meas Idd not found — quiescent current measurement missing"
fi

# [7] Zero-volt ammeter or current source in VDD rail to enable current measurement
echo "[7] 0V voltage source (ammeter) in VDD rail for current sensing"
if [[ -f "$TB" ]] && grep -qiE '^[[:space:]]*Vvdd[[:space:]]' "$TB"; then
  pass "VDD source found (Vvdd)"
else
  fail "No Vvdd source found — cannot measure supply current"
fi

# [8] Balanced input condition: INP=INN=VDD/2 (common-mode bias for Idd)
echo "[8] Input common-mode bias (INP=INN=VDD/2 or VCM)"
if [[ -f "$TB" ]] && grep -qiE '(VCM|VDD/2|vcm|{VDD\*0\.5})' "$TB"; then
  pass "Common-mode bias reference found"
else
  fail "No common-mode bias (VCM or VDD/2) found — Idd condition requires INP=INN=VDD/2"
fi

# [9] .end statement
echo "[9] .end present"
if [[ -f "$TB" ]] && grep -qi '^\s*\.end\s*$' "$TB"; then
  pass ".end found"
else
  fail ".end not found in testbench"
fi

# [10] results/ output path or .control write section
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
