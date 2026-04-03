#!/usr/bin/env python3
"""
scripts/extract/extract_metrics.py
Metric Extraction Script — SKY130 Differential-Pair Comparator
Task: characterization-first-comparator-3be.10

Parses ngspice simulation output (log files with .meas results) from:
  - PVT corner sweep: results/corners/<param>/<corner_tag>/ngspice.log
  - Monte Carlo sweep: results/mc/<param>/run_NNN.log

Produces:
  - results/extracted/<param>.json        — per-parameter corner results
  - results/extracted/<param>_mc.json     — MC stats (mean/sigma/min/max/n)
  - results/extracted/summary.csv         — flat table (all params × corners)

Usage:
  python3 scripts/extract/extract_metrics.py \\
      --spec specs/comparator_spec.yaml \\
      --results-dir results \\
      --output-dir results/extracted

  python3 scripts/extract/extract_metrics.py --help
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import sys
from pathlib import Path
from typing import Any

import yaml  # PyYAML


# ---------------------------------------------------------------------------
# Corner tag parser
# ---------------------------------------------------------------------------
CORNER_TAG_RE = re.compile(
    r"^(?P<corner>[a-z]+)_"
    r"(?P<vdd_mv>\d+)mV_"
    r"(?P<temp>n?\d+)C$"
)


def parse_corner_tag(tag: str) -> dict[str, Any]:
    """Parse 'tt_1800mV_27C' → {corner, vdd_V, temp_C}."""
    m = CORNER_TAG_RE.match(tag)
    if not m:
        return {"corner": tag, "vdd": None, "temp": None}
    temp_str = m.group("temp")
    temp_c = -int(temp_str[1:]) if temp_str.startswith("n") else int(temp_str)
    return {
        "corner": m.group("corner"),
        "vdd": round(int(m.group("vdd_mv")) / 1000.0, 3),
        "temp": temp_c,
    }


# ---------------------------------------------------------------------------
# Ngspice log parser — extracts .meas values
# ---------------------------------------------------------------------------
# Patterns:
#   t_prop_hl          =  8.234567e-09  ...
#   VOS_val            =  1.23000e-03   ...
MEAS_LINE_RE = re.compile(
    r"^\s*(?P<name>[a-z_A-Z]\w*)\s*=\s*(?P<value>[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?\d+)?)",
    re.IGNORECASE,
)
# Also handle "failed" measurements (ngspice prints "= failed")
MEAS_FAIL_RE = re.compile(r"^\s*\w+\s*=\s*failed", re.IGNORECASE)


def parse_meas_log(log_path: Path) -> dict[str, float]:
    """
    Parse ngspice log file and return {meas_name: value} for all .meas results.
    Returns empty dict if file is missing or unreadable.
    """
    results: dict[str, float] = {}
    if not log_path.exists():
        return results
    try:
        text = log_path.read_text(errors="replace")
    except OSError:
        return results

    for line in text.splitlines():
        if MEAS_FAIL_RE.match(line):
            continue  # skip failed measurements
        m = MEAS_LINE_RE.match(line)
        if m:
            try:
                results[m.group("name").lower()] = float(m.group("value"))
            except ValueError:
                pass
    return results


# ---------------------------------------------------------------------------
# Unit conversion helpers
# ---------------------------------------------------------------------------
UNIT_SCALE: dict[str, float] = {
    "ns": 1e9,   # seconds → nanoseconds
    "ms": 1e3,   # seconds → milliseconds
    "us": 1e6,   # seconds → microseconds
    "mv": 1e3,   # volts → millivolts
    "ua": 1e6,   # amperes → microamperes
    "ma": 1e3,   # amperes → milliamperes
    "v":  1.0,   # volts (no conversion)
    "a":  1.0,   # amperes (no conversion)
    "":   1.0,
}

# Map parameter names → expected ngspice measurement names (lower-case)
# The script tries each candidate in order and uses the first match.
PARAM_MEAS_CANDIDATES: dict[str, list[str]] = {
    "t_prop_hl": ["t_prop_hl"],
    "t_prop_lh": ["t_prop_lh"],
    "vos":       ["vos", "vos_val"],
    "vhyst":     ["vhyst", "vhyst_val"],
    "idd":       ["idd", "i_vdd"],
    "voh":       ["voh", "v_oh"],
    "vol":       ["vol", "v_ol"],
}


def extract_param_value(
    meas: dict[str, float], param_name: str, units: str
) -> float | None:
    """
    Find the measurement value for a parameter and convert to spec units.
    Returns None if the measurement isn't found in the log.
    """
    candidates = PARAM_MEAS_CANDIDATES.get(param_name.lower(), [param_name.lower()])
    raw_value: float | None = None
    for cand in candidates:
        if cand in meas:
            raw_value = meas[cand]
            break
    if raw_value is None:
        return None

    scale = UNIT_SCALE.get(units.lower(), 1.0)
    return round(raw_value * scale, 6)


# ---------------------------------------------------------------------------
# Pass/Fail check against spec limits
# ---------------------------------------------------------------------------

def check_pass(value: float | None, spec_min, spec_max) -> str | None:
    """Returns 'PASS', 'FAIL', or None (if value is None)."""
    if value is None:
        return None
    if spec_min is not None and value < spec_min:
        return "FAIL"
    if spec_max is not None and value > spec_max:
        return "FAIL"
    return "PASS"


# ---------------------------------------------------------------------------
# MC statistics
# ---------------------------------------------------------------------------

def compute_stats(values: list[float]) -> dict[str, float | int]:
    """Compute mean, sigma, min, max for a list of float values."""
    n = len(values)
    if n == 0:
        return {"mean": None, "sigma": None, "min": None, "max": None, "n_runs": 0}
    mean = sum(values) / n
    variance = sum((v - mean) ** 2 for v in values) / n if n > 1 else 0.0
    return {
        "mean": round(mean, 6),
        "sigma": round(math.sqrt(variance), 6),
        "min": round(min(values), 6),
        "max": round(max(values), 6),
        "n_runs": n,
    }


# ---------------------------------------------------------------------------
# Main extraction logic
# ---------------------------------------------------------------------------

def extract_corner_results(
    param: dict[str, Any],
    results_dir: Path,
    output_dir: Path,
) -> list[dict[str, Any]]:
    """
    Scan results/corners/<param_name>/ for all corner subdirs.
    Returns a list of corner result dicts.
    """
    param_name: str = param["name"]
    units: str      = param.get("units", "")
    spec_min        = param.get("min")
    spec_max        = param.get("max")

    # Map parameter name to testbench key (drop tb/ prefix)
    # e.g. t_prop_hl → tprop, vos → vos
    tb_key = param_name.lower().replace("t_prop_hl", "tprop") \
                                .replace("t_prop_lh", "tprop") \
                                .replace("vhyst", "vhyst") \
                                .replace("vos", "vos") \
                                .replace("idd", "idd") \
                                .replace("voh", "swing") \
                                .replace("vol", "swing")

    corners_dir = results_dir / "corners" / tb_key
    corner_results: list[dict[str, Any]] = []

    if corners_dir.exists():
        for corner_dir in sorted(corners_dir.iterdir()):
            if not corner_dir.is_dir():
                continue
            tag = corner_dir.name
            parsed = parse_corner_tag(tag)
            log_path = corner_dir / "ngspice.log"
            meas = parse_meas_log(log_path)
            value = extract_param_value(meas, param_name, units)
            pf = check_pass(value, spec_min, spec_max)

            corner_results.append({
                "corner_tag": tag,
                "corner": parsed["corner"],
                "vdd": parsed["vdd"],
                "temp": parsed["temp"],
                "value": value,
                "units": units,
                "pass": pf,
            })

    # Write per-parameter JSON
    out_file = output_dir / f"{param_name}.json"
    out_file.write_text(json.dumps(corner_results, indent=2))

    return corner_results


def extract_mc_results(
    param: dict[str, Any],
    results_dir: Path,
    output_dir: Path,
) -> dict[str, Any]:
    """
    Scan results/mc/<tb_key>/ for run_NNN.log files.
    Produces <param>_mc.json with mean/sigma/min/max/n_runs.
    """
    param_name: str = param["name"]
    units: str      = param.get("units", "")

    tb_key = param_name.lower().replace("t_prop_hl", "tprop") \
                                .replace("t_prop_lh", "tprop") \
                                .replace("vhyst", "vhyst") \
                                .replace("vos", "vos") \
                                .replace("idd", "idd") \
                                .replace("voh", "swing") \
                                .replace("vol", "swing")

    mc_dir = results_dir / "mc" / tb_key
    values: list[float] = []

    if mc_dir.exists():
        for log_path in sorted(mc_dir.glob("run_*.log")):
            meas = parse_meas_log(log_path)
            val = extract_param_value(meas, param_name, units)
            if val is not None:
                values.append(val)

    stats = compute_stats(values)
    stats["parameter"] = param_name
    stats["units"] = units

    out_file = output_dir / f"{param_name}_mc.json"
    out_file.write_text(json.dumps(stats, indent=2))

    return stats


def write_summary_csv(
    all_corner_results: dict[str, list[dict[str, Any]]],
    output_dir: Path,
) -> None:
    """Write flat summary.csv: parameter, corner_tag, corner, vdd, temp, value, units, pass."""
    csv_path = output_dir / "summary.csv"
    fieldnames = ["parameter", "corner_tag", "corner", "vdd", "temp", "value", "units", "pass"]

    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for param_name, results in all_corner_results.items():
            for r in results:
                writer.writerow({
                    "parameter": param_name,
                    "corner_tag": r.get("corner_tag", ""),
                    "corner": r.get("corner", ""),
                    "vdd": r.get("vdd", ""),
                    "temp": r.get("temp", ""),
                    "value": r.get("value", ""),
                    "units": r.get("units", ""),
                    "pass": r.get("pass", ""),
                })


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Extract scalar metrics from ngspice simulation logs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/extract/extract_metrics.py \\
      --spec specs/comparator_spec.yaml \\
      --results-dir results \\
      --output-dir results/extracted

  python3 scripts/extract/extract_metrics.py \\
      --spec specs/comparator_spec.yaml \\
      --results-dir results \\
      --output-dir results/extracted \\
      --param t_prop_hl
        """,
    )
    p.add_argument(
        "--spec",
        required=True,
        help="Path to comparator_spec.yaml",
    )
    p.add_argument(
        "--results-dir",
        required=True,
        help="Root results directory (contains corners/ and mc/)",
    )
    p.add_argument(
        "--output-dir",
        required=True,
        help="Directory for extracted JSON and summary.csv output",
    )
    p.add_argument(
        "--param",
        default=None,
        help="Extract only this parameter (default: all parameters in spec)",
    )
    p.add_argument(
        "--no-mc",
        action="store_true",
        help="Skip MC extraction even if results/mc/ exists",
    )
    p.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress progress output",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    spec_path    = Path(args.spec)
    results_dir  = Path(args.results_dir)
    output_dir   = Path(args.output_dir)
    quiet        = args.quiet

    # Validate inputs
    if not spec_path.exists():
        print(f"ERROR: spec file not found: {spec_path}", file=sys.stderr)
        return 1

    output_dir.mkdir(parents=True, exist_ok=True)

    # Load spec
    with spec_path.open() as f:
        spec = yaml.safe_load(f)
    parameters: list[dict[str, Any]] = spec.get("parameters", [])

    # Filter by --param if given
    if args.param:
        parameters = [p for p in parameters if p["name"].lower() == args.param.lower()]
        if not parameters:
            print(f"ERROR: parameter '{args.param}' not found in spec", file=sys.stderr)
            return 1

    if not quiet:
        print(f"Extracting {len(parameters)} parameter(s) from {results_dir}/ → {output_dir}/")

    all_corner_results: dict[str, list[dict[str, Any]]] = {}
    all_mc_stats: dict[str, dict[str, Any]] = {}

    for param in parameters:
        pname = param["name"]
        if not quiet:
            print(f"  [{pname}] corners ...", end="", flush=True)

        corner_results = extract_corner_results(param, results_dir, output_dir)
        all_corner_results[pname] = corner_results

        if not quiet:
            print(f" {len(corner_results)} corners", end="")

        if not args.no_mc:
            mc_stats = extract_mc_results(param, results_dir, output_dir)
            all_mc_stats[pname] = mc_stats
            if not quiet:
                n = mc_stats.get("n_runs", 0)
                print(f" | MC {n} runs")
        else:
            if not quiet:
                print()

    # Write flat summary.csv
    write_summary_csv(all_corner_results, output_dir)

    # Write aggregate MC summary JSON
    mc_summary_path = output_dir / "mc_summary.json"
    mc_summary_path.write_text(json.dumps(all_mc_stats, indent=2))

    if not quiet:
        print(f"\nOutput written to: {output_dir}/")
        print(f"  summary.csv, mc_summary.json, <param>.json, <param>_mc.json")

    return 0


if __name__ == "__main__":
    sys.exit(main())
