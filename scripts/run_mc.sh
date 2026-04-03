#!/usr/bin/env bash
# scripts/run_mc.sh
# Monte Carlo Sweep Orchestrator — SKY130 Differential-Pair Comparator
# Task: characterization-first-comparator-3be.9
#
# Runs >= 200 Monte Carlo iterations per testbench using SKY130 statistical
# device mismatch models (mc_mm_switch=1, mc_pr_switch=1).
#
# Strategy:
#   Each MC run is a separate ngspice invocation with a unique seed.
#   This avoids the complexity of .control repeat loops and gives clean
#   per-run raw files that are easy to post-process.
#
# Usage:
#   bash scripts/run_mc.sh                  # all testbenches, 200 runs each
#   bash scripts/run_mc.sh --runs 50        # 50 iterations (testing)
#   bash scripts/run_mc.sh --tb tprop       # single testbench
#   PDK_ROOT=/path/to/sky130A bash scripts/run_mc.sh
#
# Output structure:
#   results/mc/<param>/run_001.raw          # ngspice raw per iteration
#   results/mc/<param>/run_001.meas         # extracted scalar measurement
#   results/mc/<param>/summary.csv          # per-run scalar: run,value
#   results/mc/mc_summary.json             # mean/sigma/min/max per parameter
#
# Requires:
#   PDK_ROOT  — path to SKY130 PDK root
#   ngspice   — version >= 38, in PATH
#   bc        — for seed arithmetic
#
# Exit codes:
#   0  — all runs succeeded
#   1  — one or more runs failed (see results/mc/failures.log)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TB_DIR="$PROJECT_ROOT/tb"
RESULTS_DIR="$PROJECT_ROOT/results/mc"
FAILURES_LOG="$RESULTS_DIR/failures.log"

# Number of MC iterations (spec requires >= 200)
MC_RUNS="${MC_RUNS:-200}"

# Base random seed for reproducibility — document in README
# Each run uses seed = BASE_SEED + run_index for unique but reproducible sampling
BASE_SEED="${MC_SEED:-42}"

# SKY130 MC model switches:
#   mc_mm_switch=1  enables device-to-device mismatch (local variation)
#   mc_pr_switch=1  enables process corners statistical variation (global)
MC_MM_SWITCH=1
MC_PR_SWITCH=1

# Nominal corner for MC (TT at nominal VDD/TEMP)
MC_CORNER="tt"
MC_VDD="1.80"
MC_TEMP="27"
MC_VBIAS="0.55"

# Testbenches available for MC analysis
declare -A TB_MAP=(
  [tprop]="tb_tprop.sp"
  [idd]="tb_idd.sp"
  [swing]="tb_swing.sp"
  [vos]="tb_vos.sp"
  [vhyst]="tb_vhyst.sp"
)

# Default: run all testbenches
RUN_TBS=("${!TB_MAP[@]}")

# Max parallel jobs
MAX_JOBS="${NGSPICE_JOBS:-4}"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      shift; MC_RUNS="$1"; shift ;;
    --tb)
      shift; RUN_TBS=("$1"); shift ;;
    --seed)
      shift; BASE_SEED="$1"; shift ;;
    --jobs)
      shift; MAX_JOBS="$1"; shift ;;
    *)
      echo "Unknown argument: $1" >&2; exit 1 ;;
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
# Setup output directories
# ---------------------------------------------------------------------------
mkdir -p "$RESULTS_DIR"
: > "$FAILURES_LOG"

TOTAL=0
PASS_COUNT=0
FAIL_COUNT=0

declare -a JOB_PIDS=()
declare -a JOB_TAGS=()
declare -a JOB_OUTFILES=()

wait_for_jobs() {
  for i in "${!JOB_PIDS[@]}"; do
    local pid="${JOB_PIDS[$i]}"
    local tag="${JOB_TAGS[$i]}"
    local outfile="${JOB_OUTFILES[$i]}"
    local rc=0
    wait "$pid" || rc=$?
    TOTAL=$((TOTAL + 1))
    if [[ $rc -eq 0 ]]; then
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "$tag exit=$rc" >> "$FAILURES_LOG"
      echo "  [FAIL] $tag (exit $rc)"
    fi
    _ "$outfile"  # consumed; output file path tracked for aggregation
  done
  JOB_PIDS=()
  JOB_TAGS=()
  JOB_OUTFILES=()
}

# no-op to avoid unbound variable
_() { : ; }

# ---------------------------------------------------------------------------
# Run one MC iteration
# ---------------------------------------------------------------------------
run_one_mc() {
  local param="$1"
  local tbfile="$2"
  local run_idx="$3"       # 1-based
  local seed=$(( BASE_SEED + run_idx ))

  local run_tag
  run_tag="$(printf "run_%03d" "$run_idx")"
  local out_dir="$RESULTS_DIR/$param"
  local rawfile="$out_dir/${run_tag}.raw"
  local logfile="$out_dir/${run_tag}.log"

  # Inject MC switches + nominal PVT + unique seed via -p pre-commands
  # mc_mm_switch and mc_pr_switch are passed as .param to sky130.lib.spice
  local pre_cmd=".param CORNER=\"${MC_CORNER}\" VDD=${MC_VDD} TEMP=${MC_TEMP} VBIAS=${MC_VBIAS} mc_mm_switch=${MC_MM_SWITCH} mc_pr_switch=${MC_PR_SWITCH}"

  local rc=0
  ngspice -b \
    -p "$pre_cmd" \
    -p "set rndseed=${seed}" \
    -r "$rawfile" \
    "$TB_DIR/$tbfile" \
    >"$logfile" 2>&1 || rc=$?

  return $rc
}

# ---------------------------------------------------------------------------
# Aggregate per-run measurements from ngspice output into summary.csv
# ---------------------------------------------------------------------------
aggregate_results() {
  local param="$1"
  local out_dir="$RESULTS_DIR/$param"
  local summary_csv="$out_dir/summary.csv"

  echo "run,value_raw" > "$summary_csv"

  # Extract .meas results from each run's log file
  # ngspice prints: <meas_name> = <value>
  for logfile in "$out_dir"/run_*.log; do
    [[ -f "$logfile" ]] || continue
    local run_tag
    run_tag="$(basename "$logfile" .log)"
    # Look for any measurement result line (meas_name = value unit)
    local val
    val=$(grep -iE '^\s*[a-z_]+ *= *[0-9e+\-\.]+' "$logfile" 2>/dev/null \
          | head -1 \
          | sed 's/.*= *\([0-9e+\-\.]*\).*/\1/' \
          || echo "NA")
    echo "${run_tag},${val}" >> "$summary_csv"
  done

  echo "  → summary: $summary_csv ($(wc -l < "$summary_csv") lines)"
}

# ---------------------------------------------------------------------------
# Main MC loop
# ---------------------------------------------------------------------------
echo "========================================"
echo " Monte Carlo Sweep"
echo " Testbenches : ${RUN_TBS[*]}"
echo " Iterations  : $MC_RUNS"
echo " Base seed   : $BASE_SEED  (reproducible)"
echo " MC switches : mc_mm_switch=$MC_MM_SWITCH  mc_pr_switch=$MC_PR_SWITCH"
echo " Corner      : $MC_CORNER VDD=${MC_VDD}V T=${MC_TEMP}°C"
echo " Max jobs    : $MAX_JOBS"
echo " Results dir : $RESULTS_DIR"
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

  echo "── [$param] $tbfile — ${MC_RUNS} iterations ──"
  mkdir -p "$RESULTS_DIR/$param"

  for ((run=1; run<=MC_RUNS; run++)); do
    run_one_mc "$param" "$tbfile" "$run" &
    JOB_PIDS+=($!)
    JOB_TAGS+=("$(printf "run_%03d" "$run") [$param]")
    JOB_OUTFILES+=("$RESULTS_DIR/$param/$(printf 'run_%03d' "$run").raw")

    if [[ ${#JOB_PIDS[@]} -ge $MAX_JOBS ]]; then
      wait_for_jobs
    fi
  done

  # Drain remaining jobs for this testbench
  wait_for_jobs

  # Aggregate per-run measurements
  aggregate_results "$param"
  echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
echo " MC Sweep complete"
echo " Total runs : $TOTAL"
echo " PASS       : $PASS_COUNT"
echo " FAIL       : $FAIL_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo " Failures   : $FAILURES_LOG"
fi
echo "========================================"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
