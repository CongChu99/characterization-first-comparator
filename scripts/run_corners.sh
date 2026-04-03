#!/usr/bin/env bash
# scripts/run_corners.sh
# PVT Corner Sweep Orchestrator — SKY130 Differential-Pair Comparator
# Task: characterization-first-comparator-3be.8
#
# Runs all 5 testbenches × 5 corners × 3 temps × 2 voltages = 150 simulations.
# Writes one .raw file per (testbench, corner, vdd, temp) to:
#   results/corners/<param>/<corner_tag>/tb_<param>.raw
#
# Usage:
#   bash scripts/run_corners.sh              # all testbenches, all 30 corners
#   bash scripts/run_corners.sh --tb tprop  # single testbench
#   PDK_ROOT=/path/to/sky130A bash scripts/run_corners.sh
#
# Requires:
#   PDK_ROOT  — path to SKY130 PDK root (must be set in environment)
#   ngspice   — version ≥ 38, available in PATH
#
# Exit codes:
#   0  — all simulations succeeded
#   1  — one or more simulations failed (see results/corners/failures.log)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB_DIR="$PROJECT_ROOT/tb"
RESULTS_DIR="$PROJECT_ROOT/results/corners"
FAILURES_LOG="$RESULTS_DIR/failures.log"

# PVT corner matrix
corners=(tt ff ss fs sf)
temps=(-40 27 125)
vdds=(1.62 1.80 1.98)

# Testbenches and their parameter names
declare -A TB_MAP=(
  [tprop]="tb_tprop.sp"
  [idd]="tb_idd.sp"
  [swing]="tb_swing.sp"
  [vos]="tb_vos.sp"
  [vhyst]="tb_vhyst.sp"
)

# Default: run all testbenches unless --tb is given
RUN_TBS=("${!TB_MAP[@]}")

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tb)
      shift
      RUN_TBS=("$1")
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
if [[ -z "${PDK_ROOT:-}" ]]; then
  echo "ERROR: PDK_ROOT is not set. See README for setup instructions." >&2
  exit 1
fi

if ! command -v ngspice &>/dev/null; then
  echo "ERROR: ngspice not found in PATH. Please install ngspice >= 38." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Format VDD as millivolts (1.8 → 1800mV, 1.62 → 1620mV)
vdd_tag() {
  local vdd="$1"
  # bc for floating point: 1.62 * 1000 = 1620
  local mv
  mv=$(echo "$vdd * 1000" | bc | sed 's/\..*//')
  echo "${mv}mV"
}

# Format temperature (−40 → n40C, 27 → 27C)
temp_tag() {
  local temp="$1"
  if [[ "$temp" == -* ]]; then
    echo "n${temp#-}C"
  else
    echo "${temp}C"
  fi
}

# Build corner tag: tt_1800mV_27C
corner_tag() {
  local corner="$1" vdd="$2" temp="$3"
  echo "${corner}_$(vdd_tag "$vdd")_$(temp_tag "$temp")"
}

# ---------------------------------------------------------------------------
# Setup output directories
# ---------------------------------------------------------------------------
mkdir -p "$RESULTS_DIR"
: > "$FAILURES_LOG"   # truncate/create failures log

TOTAL=0
PASS_COUNT=0
FAIL_COUNT=0

# ---------------------------------------------------------------------------
# Max parallel jobs (default: 4 to avoid I/O thrashing)
# ---------------------------------------------------------------------------
MAX_JOBS="${NGSPICE_JOBS:-4}"
declare -a JOB_PIDS=()
declare -a JOB_TAGS=()

wait_for_jobs() {
  for i in "${!JOB_PIDS[@]}"; do
    local pid="${JOB_PIDS[$i]}"
    local tag="${JOB_TAGS[$i]}"
    local rc=0
    wait "$pid" || rc=$?
    if [[ $rc -eq 0 ]]; then
      PASS_COUNT=$((PASS_COUNT + 1))
      echo "  [OK]   $tag"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "  [FAIL] $tag (exit $rc)"
      echo "$tag exit=$rc" >> "$FAILURES_LOG"
    fi
    TOTAL=$((TOTAL + 1))
  done
  JOB_PIDS=()
  JOB_TAGS=()
}

# ---------------------------------------------------------------------------
# Run one simulation in background
# ---------------------------------------------------------------------------
run_sim() {
  local param="$1"
  local tbfile="$2"
  local corner="$3"
  local vdd="$4"
  local temp="$5"

  local ctag
  ctag="$(corner_tag "$corner" "$vdd" "$temp")"
  local out_dir="$RESULTS_DIR/$param/$ctag"
  mkdir -p "$out_dir"

  local rawfile="$out_dir/tb_${param}.raw"
  local logfile="$out_dir/ngspice.log"

  # Build ngspice pre-commands: inject corner params
  local pre_cmd=".param CORNER=\"${corner}\" VDD=${vdd} TEMP=${temp}"

  local rc=0
  ngspice -b \
    -p "$pre_cmd" \
    -r "$rawfile" \
    "$TB_DIR/$tbfile" \
    >"$logfile" 2>&1 || rc=$?

  if [[ $rc -ne 0 ]]; then
    echo "$ctag [$param] exit=$rc stderr=$(tail -1 "$logfile")" >> "$FAILURES_LOG"
    return $rc
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Main sweep loop
# ---------------------------------------------------------------------------
echo "========================================"
echo " PVT Corner Sweep"
echo " Testbenches : ${RUN_TBS[*]}"
echo " Corners     : ${corners[*]}"
echo " Temps (°C)  : ${temps[*]}"
echo " VDDs (V)    : ${vdds[*]}"
echo " Results dir : $RESULTS_DIR"
echo " Max jobs    : $MAX_JOBS"
echo "========================================"
echo ""

for param in "${RUN_TBS[@]}"; do
  tbfile="${TB_MAP[$param]:-}"
  if [[ -z "$tbfile" ]]; then
    echo "WARNING: Unknown testbench key '$param' — skipping" >&2
    continue
  fi
  if [[ ! -f "$TB_DIR/$tbfile" ]]; then
    echo "WARNING: Testbench $tbfile not found — skipping $param" >&2
    continue
  fi

  echo "── [$param] $tbfile ──"

  for corner in "${corners[@]}"; do
    for temp in "${temps[@]}"; do
      for vdd in "${vdds[@]}"; do
        ctag="$(corner_tag "$corner" "$vdd" "$temp")"

        # Launch background job
        run_sim "$param" "$tbfile" "$corner" "$vdd" "$temp" &
        JOB_PIDS+=($!)
        JOB_TAGS+=("$ctag [$param]")

        # Throttle to MAX_JOBS parallel
        if [[ ${#JOB_PIDS[@]} -ge $MAX_JOBS ]]; then
          wait_for_jobs
        fi
      done
    done
  done

  # Drain remaining jobs for this testbench
  wait_for_jobs
  echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
echo " Sweep complete"
echo " Total : $TOTAL"
echo " PASS  : $PASS_COUNT"
echo " FAIL  : $FAIL_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo " Failures logged: $FAILURES_LOG"
fi
echo "========================================"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
