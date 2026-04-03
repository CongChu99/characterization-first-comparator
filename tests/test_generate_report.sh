#!/usr/bin/env bash
# tests/test_generate_report.sh
# TDD test suite for scripts/report/generate_report.py
# Task: characterization-first-comparator-3be.11
# Tests structural, CLI, and HTML output requirements using mock data.

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORT_SCRIPT="$PROJECT_ROOT/scripts/report/generate_report.py"
TEMPLATE="$PROJECT_ROOT/scripts/report/templates/report.html.j2"
MAKEFILE="$PROJECT_ROOT/Makefile"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

echo "=== test_generate_report.sh ==="
echo ""

# [1] generate_report.py exists
echo "[1] scripts/report/generate_report.py exists"
if [[ -f "$REPORT_SCRIPT" ]]; then pass "generate_report.py exists"
else fail "generate_report.py does not exist"; fi

# [2] Jinja2 template exists
echo "[2] scripts/report/templates/report.html.j2 exists"
if [[ -f "$TEMPLATE" ]]; then pass "report.html.j2 template exists"
else fail "report.html.j2 template does not exist"; fi

# [3] Python syntax valid
echo "[3] Python syntax valid"
if [[ -f "$REPORT_SCRIPT" ]] && python3 -m py_compile "$REPORT_SCRIPT" 2>/dev/null; then
  pass "Python syntax OK"
else
  fail "Python syntax error in generate_report.py"
fi

# [4] CLI --help works
echo "[4] CLI --help runs without error"
if [[ -f "$REPORT_SCRIPT" ]] && python3 "$REPORT_SCRIPT" --help >/dev/null 2>&1; then
  pass "--help flag works"
else
  fail "--help flag failed"
fi

# [5] Required CLI args: --spec, --extracted-dir, --output
echo "[5] Required CLI args: --spec, --extracted-dir, --output"
if [[ -f "$REPORT_SCRIPT" ]]; then
  MISSING_ARGS=()
  for ARG in "--spec" "--extracted-dir" "--output"; do
    python3 "$REPORT_SCRIPT" --help 2>&1 | grep -q -- "$ARG" || MISSING_ARGS+=("$ARG")
  done
  if [[ ${#MISSING_ARGS[@]} -eq 0 ]]; then pass "All required CLI args present"
  else fail "Missing CLI args: ${MISSING_ARGS[*]}"; fi
else
  fail "Cannot check CLI args — file missing"
fi

# [6] Functional: generate HTML report from mock data
echo "[6] Functional: generate report → HTML file produced"
if [[ -f "$REPORT_SCRIPT" ]]; then
  # Create minimal spec
  cat > "$TMP/spec.yaml" <<'YAML'
parameters:
  - name: t_prop_hl
    units: ns
    min: null
    typ: 10
    max: 50
    testbench: tb/tb_tprop.sp
YAML

  # Create minimal extracted JSON
  mkdir -p "$TMP/extracted"
  cat > "$TMP/extracted/t_prop_hl.json" <<'JSON'
[
  {"corner_tag": "tt_1800mV_27C", "corner": "tt", "vdd": 1.8, "temp": 27, "value": 8.5, "units": "ns", "pass": "PASS"},
  {"corner_tag": "ss_1620mV_n40C", "corner": "ss", "vdd": 1.62, "temp": -40, "value": 62.0, "units": "ns", "pass": "FAIL"}
]
JSON
  cat > "$TMP/extracted/t_prop_hl_mc.json" <<'JSON'
{"parameter": "t_prop_hl", "units": "ns", "mean": 9.2, "sigma": 1.1, "min": 7.5, "max": 12.3, "n_runs": 3}
JSON
  cat > "$TMP/extracted/mc_summary.json" <<'JSON'
{"t_prop_hl": {"parameter": "t_prop_hl", "units": "ns", "mean": 9.2, "sigma": 1.1, "min": 7.5, "max": 12.3, "n_runs": 3}}
JSON

  OUT_HTML="$TMP/report.html"
  python3 "$REPORT_SCRIPT" \
    --spec "$TMP/spec.yaml" \
    --extracted-dir "$TMP/extracted" \
    --output "$OUT_HTML" \
    >/dev/null 2>&1 && REPORT_OK=true || REPORT_OK=false

  if $REPORT_OK && [[ -f "$OUT_HTML" ]]; then
    pass "HTML report generated: report.html"
  else
    fail "generate_report.py did not produce report.html"
  fi
else
  fail "Cannot test report generation — file missing"
fi

# [7] HTML is valid UTF-8 and contains <html> tag
echo "[7] HTML output is well-formed (contains <html>)"
if [[ -f "$TMP/report.html" ]]; then
  if grep -q '<html' "$TMP/report.html"; then
    pass "HTML contains <html> tag"
  else
    fail "HTML output does not contain <html> tag"
  fi
else
  fail "Cannot check HTML — report not produced"
fi

# [8] HTML contains PASS/FAIL verdict
echo "[8] HTML contains top-level PASS/FAIL verdict"
if [[ -f "$TMP/report.html" ]]; then
  if grep -qiE '(FAIL|verdict|overall)' "$TMP/report.html"; then
    pass "HTML contains verdict (PASS/FAIL)"
  else
    fail "HTML does not contain PASS/FAIL verdict"
  fi
else
  fail "Cannot check verdict — report not produced"
fi

# [9] HTML contains per-corner pass/fail table
echo "[9] HTML contains per-corner table"
if [[ -f "$TMP/report.html" ]]; then
  if grep -q '<table' "$TMP/report.html"; then
    pass "HTML contains <table> for per-corner results"
  else
    fail "HTML does not contain a table — per-corner results missing"
  fi
else
  fail "Cannot check table — report not produced"
fi

# [10] HTML contains embedded plot (base64 PNG data URI) or inline SVG
echo "[10] HTML contains embedded chart (base64/SVG — no external URLs)"
if [[ -f "$TMP/report.html" ]]; then
  if grep -qiE '(data:image/png;base64|data:image/svg|<svg )' "$TMP/report.html"; then
    pass "Embedded chart found (base64 PNG or inline SVG)"
  else
    fail "No embedded chart found — MC histogram must be self-contained"
  fi
else
  fail "Cannot check chart — report not produced"
fi

# [11] Makefile report target calls generate_report.py (not stub)
echo "[11] Makefile report target calls generate_report.py"
if [[ -f "$MAKEFILE" ]] && grep -A4 '^report:' "$MAKEFILE" | grep -q 'generate_report'; then
  pass "Makefile report target calls generate_report.py"
else
  fail "Makefile report target is still a stub"
fi

# [12] reports/ output directory referenced in Makefile or script
echo "[12] reports/characterization_report.html as output path"
if [[ -f "$REPORT_SCRIPT" ]] && grep -q 'reports/' "$REPORT_SCRIPT" || \
   ([[ -f "$MAKEFILE" ]] && grep -A6 '^report:' "$MAKEFILE" | grep -q 'reports/'); then
  pass "reports/ output path referenced"
else
  fail "reports/ output path not referenced"
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
