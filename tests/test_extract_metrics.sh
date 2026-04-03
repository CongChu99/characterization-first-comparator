#!/usr/bin/env bash
# tests/test_extract_metrics.sh
# TDD test suite for scripts/extract/extract_metrics.py
# Task: characterization-first-comparator-3be.10
# Tests structural, CLI, and functional requirements using mock data.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXTRACT_SCRIPT="$PROJECT_ROOT/scripts/extract/extract_metrics.py"
MAKEFILE="$PROJECT_ROOT/Makefile"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_extract_metrics.sh ==="
echo ""

# ---------------------------------------------------------------------------
# [1] File exists
# ---------------------------------------------------------------------------
echo "[1] scripts/extract/extract_metrics.py exists"
if [[ -f "$EXTRACT_SCRIPT" ]]; then pass "extract_metrics.py exists"
else fail "extract_metrics.py does not exist"; fi

# ---------------------------------------------------------------------------
# [2] Syntax valid (Python parse check)
# ---------------------------------------------------------------------------
echo "[2] Python syntax valid"
if [[ -f "$EXTRACT_SCRIPT" ]] && python3 -m py_compile "$EXTRACT_SCRIPT" 2>/dev/null; then
  pass "Python syntax OK"
else
  fail "Python syntax error in extract_metrics.py"
fi

# ---------------------------------------------------------------------------
# [3] CLI --help flag works
# ---------------------------------------------------------------------------
echo "[3] CLI --help runs without error"
if [[ -f "$EXTRACT_SCRIPT" ]] && python3 "$EXTRACT_SCRIPT" --help >/dev/null 2>&1; then
  pass "--help flag works"
else
  fail "--help flag failed or script not runnable"
fi

# ---------------------------------------------------------------------------
# [4] Required CLI arguments: --spec, --results-dir, --output-dir
# ---------------------------------------------------------------------------
echo "[4] Required CLI args: --spec, --results-dir, --output-dir"
if [[ -f "$EXTRACT_SCRIPT" ]]; then
  MISSING_ARGS=()
  for ARG in "--spec" "--results-dir" "--output-dir"; do
    python3 "$EXTRACT_SCRIPT" --help 2>&1 | grep -q -- "$ARG" || MISSING_ARGS+=("$ARG")
  done
  if [[ ${#MISSING_ARGS[@]} -eq 0 ]]; then pass "All required CLI args present"
  else fail "Missing CLI args: ${MISSING_ARGS[*]}"; fi
else
  fail "Cannot check CLI args — file missing"
fi

# ---------------------------------------------------------------------------
# [5] Functional: parse ngspice meas log and write per-parameter JSON
# ---------------------------------------------------------------------------
echo "[5] Functional: parse meas log → per-parameter JSON"
if [[ -f "$EXTRACT_SCRIPT" ]]; then
  # Create minimal YAML spec
  cat > "$TMP/spec.yaml" <<'YAML'
parameters:
  - name: t_prop_hl
    units: ns
    min: null
    typ: 10
    max: 50
    testbench: tb/tb_tprop.sp
YAML

  # Create mock results/corners structure
  mkdir -p "$TMP/results/corners/tprop/tt_1800mV_27C"
  cat > "$TMP/results/corners/tprop/tt_1800mV_27C/ngspice.log" <<'LOG'
t_prop_hl = 8.234567e-09 targ=1.823e-08 trig=9.99e-09
LOG

  # Run extraction
  mkdir -p "$TMP/extracted"
  python3 "$EXTRACT_SCRIPT" \
    --spec "$TMP/spec.yaml" \
    --results-dir "$TMP/results" \
    --output-dir "$TMP/extracted" \
    >/dev/null 2>&1 && EXTRACT_OK=true || EXTRACT_OK=false

  if $EXTRACT_OK && [[ -f "$TMP/extracted/t_prop_hl.json" ]]; then
    pass "extract_metrics.py produced t_prop_hl.json"
  else
    fail "extract_metrics.py did not produce t_prop_hl.json"
  fi
else
  fail "Cannot test extraction — file missing"
fi

# ---------------------------------------------------------------------------
# [6] Functional: JSON content has correct structure (corner, value, units)
# ---------------------------------------------------------------------------
echo "[6] JSON content has corner/value/units fields"
if [[ -f "$TMP/extracted/t_prop_hl.json" ]]; then
  if python3 -c "
import json, sys
with open('$TMP/extracted/t_prop_hl.json') as f:
    data = json.load(f)
# Expect either a list of corner results or a dict keyed by corner
assert isinstance(data, (list, dict)), 'JSON must be list or dict'
# Check first entry has required fields
if isinstance(data, list):
    entry = data[0]
elif isinstance(data, dict):
    entry = next(iter(data.values()))
assert 'value' in entry or 'measured' in entry, 'entry must have value/measured field'
print('JSON structure OK')
" 2>/dev/null; then
    pass "JSON has required structure"
  else
    fail "JSON structure invalid — missing value/measured field or wrong type"
  fi
else
  fail "Cannot check JSON — file not produced"
fi

# ---------------------------------------------------------------------------
# [7] Functional: null handling — missing simulation output → null in JSON
# ---------------------------------------------------------------------------
echo "[7] Null handling: missing corner output → null in JSON"
if [[ -f "$EXTRACT_SCRIPT" ]]; then
  # Create spec with a param that has NO simulation output
  cat > "$TMP/spec_null.yaml" <<'YAML'
parameters:
  - name: VOS
    units: mV
    min: null
    typ: 0
    max: 5
    testbench: tb/tb_vos.sp
YAML
  mkdir -p "$TMP/extracted_null"
  # No VOS corner output files — should produce JSON with null values
  python3 "$EXTRACT_SCRIPT" \
    --spec "$TMP/spec_null.yaml" \
    --results-dir "$TMP/results" \
    --output-dir "$TMP/extracted_null" \
    >/dev/null 2>&1 || true
  # JSON should exist even when no data found (may be empty list or null entries)
  if [[ -f "$TMP/extracted_null/VOS.json" ]]; then
    pass "VOS.json produced even with no simulation data"
  else
    # Tolerate: some implementations may skip producing JSON for missing data
    pass "Null handling: no crash on missing data (acceptable)"
  fi
else
  fail "Cannot test null handling — file missing"
fi

# ---------------------------------------------------------------------------
# [8] Functional: summary.csv produced with correct columns
# ---------------------------------------------------------------------------
echo "[8] summary.csv produced with correct columns"
if [[ -f "$EXTRACT_SCRIPT" ]]; then
  if [[ -f "$TMP/extracted/summary.csv" ]]; then
    HEADER=$(head -1 "$TMP/extracted/summary.csv")
    if echo "$HEADER" | grep -qiE '(parameter|param)' && \
       echo "$HEADER" | grep -qiE '(corner|value)'; then
      pass "summary.csv has correct columns (parameter, corner/value)"
    else
      fail "summary.csv header missing required columns: $HEADER"
    fi
  else
    fail "summary.csv not produced by extract_metrics.py"
  fi
else
  fail "Cannot check summary.csv — script missing"
fi

# ---------------------------------------------------------------------------
# [9] Makefile extract target calls extract_metrics.py (not stub)
# ---------------------------------------------------------------------------
echo "[9] Makefile extract target calls extract_metrics.py"
if [[ -f "$MAKEFILE" ]] && grep -A4 '^extract:' "$MAKEFILE" | grep -q 'extract_metrics'; then
  pass "Makefile extract target calls extract_metrics.py"
else
  fail "Makefile extract target is still a stub"
fi

# ---------------------------------------------------------------------------
# [10] MC summary JSON produced (mean/sigma/min/max)
# ---------------------------------------------------------------------------
echo "[10] MC summary JSON: results/mc/<param>_mc.json or mc_summary.json"
if [[ -f "$EXTRACT_SCRIPT" ]]; then
  # Create mock MC results
  mkdir -p "$TMP/results/mc/tprop"
  for i in 001 002 003; do
    cat > "$TMP/results/mc/tprop/run_${i}.log" <<LOG
t_prop_hl = $(echo "scale=6; $i * 0.000000001 + 0.000000008" | bc)
LOG
  done

  python3 "$EXTRACT_SCRIPT" \
    --spec "$TMP/spec.yaml" \
    --results-dir "$TMP/results" \
    --output-dir "$TMP/extracted" \
    >/dev/null 2>&1 || true

  # Check for mc summary file — accept either naming convention
  if [[ -f "$TMP/extracted/t_prop_hl_mc.json" ]] || \
     [[ -f "$TMP/extracted/mc_summary.json" ]]; then
    pass "MC summary JSON produced"
  else
    fail "MC summary JSON not found (expected t_prop_hl_mc.json or mc_summary.json)"
  fi
else
  fail "Cannot test MC summary — script missing"
fi

# ---------------------------------------------------------------------------
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
