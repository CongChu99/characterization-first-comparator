# Proposal: Characterization-First Comparator / Reference / Opamp Block

## Why

The open-source analog IC ecosystem (SKY130 PDK, ngspice, xschem) has matured enough to support serious circuit design, but a critical gap remains: there is no lightweight, reproducible methodology for analog IP characterization that an individual designer can adopt without heavyweight tooling.

Most open-source analog IP projects ship a schematic and a waveform screenshot. No spec table. No PVT corner sweep. No pass/fail verdict. This makes it impossible for a third party to evaluate, reuse, or trust the IP.

The closest solution — Efabless CACE — imposed a heavyweight YAML framework tied to Efabless infrastructure that shut down in early 2025. The vacuum it left has not been filled.

This project establishes a **characterization-first methodology**: the spec table is defined before the schematic is drawn, testbenches are built as part of the design process, and the deliverable is not just a circuit but a structured, reproducible characterization report. The static differential-pair comparator on SKY130 is the first reference implementation.

## What Changes

This project defines a new open-source analog IP deliverable format:
**characterization-first analog IP**.

Instead of treating characterization as a late-stage verification activity, this project makes the following artifacts part of the design itself from day one:

- machine-readable specifications,
- structured measurement harnesses,
- automated sweep execution,
- metric extraction,
- and pass/fail reporting.

### Added Capabilities

- YAML spec source of truth for analog performance targets and measurement conditions
- Reusable SPICE testbench harnesses organized by metric
- Hybrid batch automation with Makefile, ngspice, and Python
- Structured result extraction into JSON/CSV
- Automatic spec-vs-result pass/fail report generation
- A reproducible SKY130 reference comparator demonstrating the workflow end to end

### Scope Impact

This is a new standalone project. No existing code is changed or removed.

### Why This Matters

The key change is methodological: the project is designed to make analog IP easier to characterize, review, compare, and reuse — not just simulate once and present as waveforms.

## Capabilities

### New Capabilities

- `spec-table`: YAML file defining all measured parameters with min/typ/max limits, units, test conditions, and measurement method. Version-controlled alongside the schematic. This is the "contract" that drives all downstream testbenches and reports.

- `testbench-harness`: One ngspice SPICE testbench per measured parameter (propagation delay, input offset voltage, hysteresis, quiescent current, output swing VOH/VOL). Each testbench is parameterized for corner injection (process corner, VDD, temperature).

- `pvt-sweep`: Makefile + shell orchestration that runs ngspice in batch mode across all 5 process corners (TT/FF/SS/FS/SF) × 3 temperatures (-40°C, 27°C, 125°C) × 2 supply voltages (nominal ±10%) = 30 corner points per parameter.

- `monte-carlo-sweep`: ngspice `.control` script executing ≥200 MC runs per parameter using SKY130 statistical device mismatch models. Extracts mean, σ, min, max.

- `metric-extraction`: Python scripts (spicelib-based) that parse ngspice raw output files and produce structured per-corner metric tables in JSON and CSV.

- `report-generation`: Python script (Jinja2 + matplotlib) that combines spec table + extracted metrics into an HTML/Markdown pass/fail characterization report — per-corner pass/fail table, MC histograms, overall PASS/FAIL verdict.

- `reproducibility-entry-point`: `make characterize` command that runs the full flow (corner sweep → MC → extract → report) from a clean checkout. Documents required tool versions and PDK path configuration.

- `reference-comparator`: Fully characterized static differential-pair comparator on SKY130 — schematic (xschem), spec table (YAML), testbenches, sweep results, and final characterization report — serving as the worked example of the methodology.

## Scope

### In Scope

- Comparator spec table in YAML (all measured parameters: t_prop, VOS, VHYST, Idd, VOH, VOL)
- Static differential-pair comparator schematic in xschem (SKY130 PDK)
- Testbench harnesses for each measured parameter (ngspice, standalone `.sp` files)
- PVT corner sweep: 5 corners × 3 temperatures × 2 supply voltages (30 points minimum)
- Monte Carlo sweep: ≥200 runs per parameter, SKY130 mismatch models
- Metric extraction: Python + spicelib → JSON/CSV output
- Pass/fail report: HTML or Markdown with corner table, MC histograms, overall verdict
- `make characterize` single-command entry point
- Corner model validation script (sanity check before full sweep)
- README with methodology explanation and tool setup instructions

### Out of Scope (Non-Goals)

- StrongARM / dynamic latch comparator topology
- Opamp block, voltage reference block (planned v2/v3)
- Post-layout (extracted netlist) characterization
- Xyce or Spectre simulator support
- GF180MCU or any non-SKY130 PDK
- CACE YAML compatibility or migration layer
- Auto-sizing or specification-driven topology generation
- PDF report generation
- Tapeout-ready LVS/DRC-clean layout

## Success Criteria

- `make characterize` runs to completion from a clean git clone with only ngspice + Python (+ spicelib/Jinja2/matplotlib) installed — no undocumented dependencies
- Characterization report covers all 30 PVT corners for every parameter in the spec table
- Monte Carlo analysis produces mean/σ/min/max for each parameter with ≥200 runs
- Every parameter in the spec table has a corresponding testbench and a pass/fail result in the report
- A designer unfamiliar with the project can reproduce all results end-to-end in under 30 minutes following the README
- The characterization report is self-contained and readable without running any tool — usable as a datasheet substitute for IP evaluation

## Impact

**Community positioning**: Fills the void left by Efabless/CACE with a simpler, standalone alternative. No platform dependency, no heavyweight YAML framework. Targets the post-Efabless open-silicon community (SSCS PICO Chipathon, Tiny Tapeout with IHP/GF180MCU, FOSSi/FSiC contributors).

**Competitive differentiation**: Lower friction than CACE (no framework to adopt, runs on bare ngspice + Python); better documented than cicsim; open and reproducible vs. Cadence ADE.

**Downstream projects**: Establishes the template and methodology that opamp and reference block characterization (v2/v3) will follow. The YAML spec schema and report format are designed for reuse across block types.
