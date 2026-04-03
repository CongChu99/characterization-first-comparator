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

# Detect PDK model library path — try all known layouts
PDK_LIB_VOLARE="$PDK_ROOT/libs.ref/sky130_fd_pr/spice/sky130.lib.spice"
PDK_LIB_OPEN_PDKS="$PDK_ROOT/share/pdk/sky130A/libs.ref/sky130_fd_pr/spice/sky130.lib.spice"
PDK_LIB_VOLARE_A="$PDK_ROOT/sky130A/libs.tech/ngspice/sky130.lib.spice"
PDK_LIB_VOLARE_REF="$PDK_ROOT/sky130A/libs.ref/sky130_fd_pr/spice/sky130.lib.spice"

if [ -f "$PDK_LIB_VOLARE" ]; then
    PDK_LIB="$PDK_LIB_VOLARE"
elif [ -f "$PDK_LIB_OPEN_PDKS" ]; then
    PDK_LIB="$PDK_LIB_OPEN_PDKS"
elif [ -f "$PDK_LIB_VOLARE_A" ]; then
    PDK_LIB="$PDK_LIB_VOLARE_A"
elif [ -f "$PDK_LIB_VOLARE_REF" ]; then
    PDK_LIB="$PDK_LIB_VOLARE_REF"
else
    echo "[ERROR] SKY130 model library not found. Tried:" >&2
    echo "        (1) $PDK_LIB_VOLARE" >&2
    echo "        (2) $PDK_LIB_OPEN_PDKS" >&2
    echo "        (3) $PDK_LIB_VOLARE_A" >&2
    echo "        (4) $PDK_LIB_VOLARE_REF" >&2
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

    # Generate a self-contained per-corner validation netlist
    WRAPPER="$TMPDIR_RUN/corner_${CORNER}.sp"
    cat > "$WRAPPER" <<EOF
* Auto-generated corner validation netlist: $CORNER
.param CORNER=$CORNER

* Load SKY130 model library with this corner
.lib $PDK_LIB $CORNER

* Minimal test circuit: CMOS inverter-like stage
M1 vout vg vdd vdd sky130_fd_pr__pfet_01v8 W=1u L=150n
M2 vout vg gnd gnd sky130_fd_pr__nfet_01v8 W=1u L=150n

Vdd vdd gnd DC 1.8
Vg  vg  gnd DC 0.9

.op
.end
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
