#!/usr/bin/env bash
# tests/test_netlist.sh
# TDD test suite for comparator SPICE netlist
# Task: characterization-first-comparator-3be.3

set -euo pipefail

PASS=0
FAIL=0
ERRORS=()

# Resolve project root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

NETLIST="$PROJECT_ROOT/netlist/comparator.spice"
TOPONOTES="$PROJECT_ROOT/docs/topology-notes.md"

pass() {
    echo "  PASS: $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  FAIL: $1"
    FAIL=$((FAIL + 1))
    ERRORS+=("$1")
}

echo "=== test_netlist.sh ==="
echo ""

# --- Test 1: netlist file exists ---
echo "[1] netlist/comparator.spice exists"
if [[ -f "$NETLIST" ]]; then
    pass "netlist/comparator.spice exists"
else
    fail "netlist/comparator.spice does not exist (path: $NETLIST)"
fi

# --- Test 2: .subckt comparator declaration ---
echo "[2] .subckt comparator declaration present"
if [[ -f "$NETLIST" ]] && grep -qi '\.subckt[[:space:]]\+comparator' "$NETLIST"; then
    pass ".subckt comparator found"
else
    fail ".subckt comparator not found in netlist"
fi

# --- Test 3: All 5 required ports present on .subckt line ---
echo "[3] All 5 ports present: INP INN VDD VSS OUT"
if [[ -f "$NETLIST" ]]; then
    SUBCKT_LINE=$(grep -i '\.subckt[[:space:]]\+comparator' "$NETLIST" | head -1)
    MISSING_PORTS=()
    for PORT in INP INN VDD VSS OUT; do
        if ! echo "$SUBCKT_LINE" | grep -qi "\b${PORT}\b"; then
            MISSING_PORTS+=("$PORT")
        fi
    done
    if [[ ${#MISSING_PORTS[@]} -eq 0 ]]; then
        pass "All 5 ports found: INP INN VDD VSS OUT"
    else
        fail "Missing ports on .subckt line: ${MISSING_PORTS[*]}"
    fi
else
    fail "Cannot check ports — netlist file missing"
fi

# --- Test 4: Uses sky130_fd_pr__nfet_01v8 (NMOS devices) ---
echo "[4] Uses sky130_fd_pr__nfet_01v8 (NMOS)"
if [[ -f "$NETLIST" ]] && grep -q 'sky130_fd_pr__nfet_01v8' "$NETLIST"; then
    pass "sky130_fd_pr__nfet_01v8 found"
else
    fail "sky130_fd_pr__nfet_01v8 not found in netlist"
fi

# --- Test 5: Uses sky130_fd_pr__pfet_01v8 (PMOS devices) ---
echo "[5] Uses sky130_fd_pr__pfet_01v8 (PMOS)"
if [[ -f "$NETLIST" ]] && grep -q 'sky130_fd_pr__pfet_01v8' "$NETLIST"; then
    pass "sky130_fd_pr__pfet_01v8 found"
else
    fail "sky130_fd_pr__pfet_01v8 not found in netlist"
fi

# --- Test 6: .ends comparator present ---
echo "[6] .ends comparator present"
if [[ -f "$NETLIST" ]] && grep -qi '\.ends[[:space:]]\+comparator' "$NETLIST"; then
    pass ".ends comparator found"
else
    fail ".ends comparator not found in netlist"
fi

# --- Test 7: docs/topology-notes.md exists ---
echo "[7] docs/topology-notes.md exists"
if [[ -f "$TOPONOTES" ]]; then
    pass "docs/topology-notes.md exists"
else
    fail "docs/topology-notes.md does not exist (path: $TOPONOTES)"
fi

# --- Summary ---
echo ""
echo "==============================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    echo "FAILED tests:"
    for ERR in "${ERRORS[@]}"; do
        echo "  - $ERR"
    done
    echo "==============================="
    exit 1
else
    echo "ALL TESTS PASSED"
    echo "==============================="
    exit 0
fi
