#!/usr/bin/env bash
# scripts/validate_corners.sh
# Verifies SKY130 corner model files are loadable by ngspice before any sweep runs.
# Runs a minimal DC operating point simulation for each of the 5 PVT corners.
#
# Usage:
#   PDK_ROOT=/path/to/sky130A bash scripts/validate_corners.sh
#
# Exit codes:
#   0 — all corners validated
#   1 — one or more corners failed, or PDK_ROOT missing/invalid

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETLIST="$SCRIPT_DIR/corner_check.sp"

CORNERS=(tt ff ss fs sf)
CORNER_LABELS=(TT FF SS FS SF)

# ---------------------------------------------------------------------------
# PDK_ROOT validation
# ---------------------------------------------------------------------------
if [ -z "${PDK_ROOT:-}" ]; then
    echo "[ERROR] PDK_ROOT is not set." >&2
    echo "        export PDK_ROOT=/path/to/sky130A" >&2
    exit 1
fi

# Detect PDK model library path — try both common layouts
PDK_LIB_VOLARE="$PDK_ROOT/libs.ref/sky130_fd_pr/spice/sky130.lib.spice"
PDK_LIB_OPEN_PDKS="$PDK_ROOT/share/pdk/sky130A/libs.ref/sky130_fd_pr/spice/sky130.lib.spice"

if [ -f "$PDK_LIB_VOLARE" ]; then
    PDK_LIB="$PDK_LIB_VOLARE"
elif [ -f "$PDK_LIB_OPEN_PDKS" ]; then
    PDK_LIB="$PDK_LIB_OPEN_PDKS"
else
    echo "[ERROR] SKY130 model library not found. Tried:" >&2
    echo "        (1) $PDK_LIB_VOLARE" >&2
    echo "        (2) $PDK_LIB_OPEN_PDKS" >&2
    exit 1
fi

echo "[INFO] Using PDK model library: $PDK_LIB"

# ---------------------------------------------------------------------------
# Corner validation loop
# ---------------------------------------------------------------------------
PASS_ALL=true
TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

for i in "${!CORNERS[@]}"; do
    CORNER="${CORNERS[$i]}"
    LABEL="${CORNER_LABELS[$i]}"

    # Generate a per-corner wrapper netlist that overrides .param CORNER
    WRAPPER="$TMPDIR_RUN/corner_${CORNER}.sp"
    cat > "$WRAPPER" <<EOF
* Auto-generated wrapper for corner: $CORNER
.param CORNER=$CORNER
.param PDK_ROOT="$PDK_ROOT"
.include $NETLIST
EOF

    # Run ngspice in batch mode; capture stdout+stderr
    OUTPUT=$(ngspice -b -o /dev/null "$WRAPPER" 2>&1) && NG_EXIT=0 || NG_EXIT=$?

    # Determine PASS/FAIL: non-zero exit OR output contains error keywords
    # ngspice sometimes exits 0 even on model load errors, so scan output too.
    REASON=""
    if [ "$NG_EXIT" -ne 0 ]; then
        REASON="ngspice exited with code $NG_EXIT"
    elif echo "$OUTPUT" | grep -qiE "(^|\s)(Error|fatal)(\s|:|\.|$)"; then
        REASON="$(echo "$OUTPUT" | grep -iE "(^|\s)(Error|fatal)(\s|:|\.|$)" | head -1)"
    fi

    if [ -z "$REASON" ]; then
        echo "[PASS] $LABEL"
    else
        echo "[FAIL] $LABEL — $REASON"
        PASS_ALL=false
    fi
done

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
if $PASS_ALL; then
    echo "[PASS] TT FF SS FS SF — all corners validated"
    exit 0
else
    exit 1
fi
