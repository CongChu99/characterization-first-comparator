#!/usr/bin/env bash
# tests/test_tb_vos.sh
# TDD test suite for tb/tb_vos.sp
# Task: characterization-first-comparator-3be.6
# Tests structural and content requirements before running ngspice.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB="$PROJECT_ROOT/tb/tb_vos.sp"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_tb_vos.sh ==="
echo ""

# [1] File exists
echo "[1] tb/tb_vos.sp exists"
if [[ -f "$TB" ]]; then pass "tb/tb_vos.sp exists"
else fail "tb/tb_vos.sp does not exist"; fi

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
  fail ".dc analysis not found — VOS requires sweeping INP to find crossing point"
fi

# [6] .meas for VOS (input offset voltage)
echo "[6] .meas VOS declared"
if [[ -f "$TB" ]] && grep -qiE '\.meas.*(VOS|vos|V_OS|offset)' "$TB"; then
  pass ".meas VOS found"
else
  fail ".meas VOS not found — input offset voltage measurement missing"
fi

# [7] INN held at VDD/2 (reference for offset measurement)
echo "[7] INN reference at VDD/2"
if [[ -f "$TB" ]] && grep -qiE '(VDD/2|vcm|VCM|{VDD\*0\.5})' "$TB"; then
  pass "VDD/2 / VCM reference found"
else
  fail "No VDD/2 reference found — INN must be at VDD/2 for VOS measurement"
fi

# [8] INP swept from low to high (DC sweep stimulus)
echo "[8] INP voltage source declared for DC sweep"
if [[ -f "$TB" ]] && grep -qiE '^[[:space:]]*(Vinp|Vinm)[[:space:]]' "$TB"; then
  pass "INP voltage source found"
else
  fail "No INP voltage source (Vinp) found"
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
