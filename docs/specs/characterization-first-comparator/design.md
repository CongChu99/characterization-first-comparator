# Design: Characterization-First Comparator / Reference / Opamp Block

## Context

SKY130 open-source analog projects are reproducible at the circuit level, but not yet consistently reproducible at the **characterization deliverable** level.

This project introduces a characterization-first methodology in which the analog block is accompanied by:

- a machine-readable specification,
- reusable metric-specific testbenches,
- automated sweep execution,
- structured metric extraction,
- and a generated pass/fail report.

The goal is not just to publish a comparator schematic, but to publish an analog block together with a repeatable evaluation workflow.

## Architecture Overview

The system is structured as a 5-stage artifact pipeline:

1. **Spec Definition**
   YAML source of truth for target metrics and acceptance limits.

2. **Testbench Construction**
   One reusable ngspice harness per measured metric.

3. **Characterization Execution**
   Automated PVT and Monte Carlo runs from a top-level command interface.

4. **Metric Extraction**
   Conversion of simulator outputs into structured result artifacts.

5. **Report Generation**
   Automated production of characterization summaries and pass/fail evaluation.

Each stage is runnable in isolation and emits explicit output artifacts for downstream use. This keeps the flow modular, inspectable, and reusable for future analog blocks beyond the first comparator example.

This architecture is intended to be reusable for future blocks such as references and op-amps, not only for the initial comparator example.

## Components

### Component 1: Spec Table (`specs/`)
- **Purpose**: Defines the acceptance contract for the analog block. Contains all measured parameters with min/typ/max limits, units, test conditions, and measurement methods. Drives testbench naming, extraction logic, and report headers.
- **Interface**: Input — designer-authored `comparator_spec.yaml`; Output — validated spec data consumed by extraction and report components
- **Dependencies**: None (first in the pipeline)

### Component 2: Testbench Harness (`tb/`)
- **Purpose**: One standalone ngspice `.sp` file per measured parameter. Each testbench instantiates the comparator DUT with SKY130 models, applies the appropriate stimulus, and writes simulation output to `results/raw/`. Accepts corner/VDD/TEMP as runtime parameters — no hardcoded corners.
- **Interface**: Input — DUT netlist (`netlist/comparator.spice`), `PDK_ROOT`, corner parameters; Output — ngspice `.raw` or `.csv` output files in `results/`
- **Dependencies**: Comparator netlist, SKY130 PDK corner model files

### Component 3: Sweep Orchestration (`scripts/` + `Makefile`)
- **Purpose**: Drives the full PVT matrix (5 corners × 3 temperatures × 2 voltages) and Monte Carlo runs by invoking ngspice batch mode per corner point. Handles parallel execution, failure logging, and intermediate result collection.
- **Interface**: Input — testbench `.sp` files, corner definitions; Output — per-corner result files in `results/corners/` and `results/mc/`; `failures.log` for any simulation errors
- **Dependencies**: Testbench harness, ngspice ≥38, Bash

### Component 4: Metric Extraction (`scripts/extract/`)
- **Purpose**: Parses ngspice raw/CSV output files using spicelib and extracts scalar metric values per corner. Produces structured JSON per parameter and a consolidated `summary.csv`. Handles missing/failed simulation output gracefully.
- **Interface**: Input — `results/corners/` and `results/mc/` directories; Output — `results/extracted/<param>.json`, `results/summary.csv`
- **Dependencies**: Python ≥3.10, spicelib, pandas

### Component 5: Report Generator (`scripts/report/`)
- **Purpose**: Combines spec table (YAML) with extracted metrics (JSON/CSV) to produce a self-contained HTML characterization report. Includes per-corner pass/fail table, MC histograms, and top-level PASS/FAIL verdict.
- **Interface**: Input — `specs/comparator_spec.yaml`, `results/extracted/`, `results/summary.csv`; Output — `reports/characterization_report.html`
- **Dependencies**: Python ≥3.10, Jinja2, matplotlib

## Data Model

**Spec Entry** (YAML, one per parameter in `comparator_spec.yaml`):
```yaml
- name: t_prop_hl
  description: Propagation delay, high-to-low output transition
  units: ns
  min: null
  typ: 10
  max: 50
  condition: "VDD=1.8V, Vin_step=100mV, CL=10fF, T=27°C"
  measurement_method: "50% input crossing to 50% output crossing"
  testbench: tb/tb_tprop.sp
```

**Corner Tag** (string key encoding one simulation point):
```
<corner>_<vdd_mv>mV_<temp_c>C
e.g.: tt_1800mV_27C, ff_1980mV_125C, ss_1620mV_n40C
```

**Extracted Result** (JSON, one file per parameter `results/extracted/<param>.json`):
```json
{
  "parameter": "t_prop_hl",
  "units": "ns",
  "corners": [
    { "tag": "tt_1800mV_27C", "corner": "tt", "vdd": 1.8, "temp": 27, "value": 9.4, "pass": true },
    { "tag": "ss_1620mV_n40C", "corner": "ss", "vdd": 1.62, "temp": -40, "value": 62.1, "pass": false }
  ]
}
```

**MC Summary** (JSON, one file per parameter `results/mc/<param>_mc.json`):
```json
{
  "parameter": "t_prop_hl",
  "units": "ns",
  "n_runs": 200,
  "mean": 11.2,
  "sigma": 1.8,
  "min": 7.9,
  "max": 16.4
}
```

**Summary CSV** (`results/summary.csv`): one row per (parameter, corner) combination — columns: `parameter, corner, vdd, temp, value, units, pass`

## Directory Layout

```
characterization-first-comparator/
├── specs/
│   └── comparator_spec.yaml       # Spec table — source of truth
├── schematic/
│   └── comparator.sch             # xschem schematic
├── netlist/
│   └── comparator.spice           # Exported netlist from xschem
├── tb/
│   ├── tb_tprop.sp                # Propagation delay testbench
│   ├── tb_vos.sp                  # Input offset voltage testbench
│   ├── tb_vhyst.sp                # Hysteresis testbench
│   ├── tb_idd.sp                  # Quiescent current testbench
│   └── tb_swing.sp                # VOH/VOL testbench
├── scripts/
│   ├── run_corners.sh             # PVT sweep orchestration
│   ├── run_mc.sh                  # Monte Carlo orchestration
│   ├── validate_corners.sh        # Corner model validation
│   ├── extract/
│   │   └── extract_metrics.py     # spicelib-based metric extraction
│   └── report/
│       ├── generate_report.py     # Jinja2 + matplotlib report generator
│       └── templates/
│           └── report.html.j2     # HTML report template
├── results/                       # Generated — gitignored
│   ├── corners/
│   ├── mc/
│   ├── extracted/
│   └── summary.csv
├── reports/                       # Generated report — committed
│   └── characterization_report.html
├── Makefile
├── requirements.txt
└── README.md
```

## Goals / Non-Goals

**Goals:**
- Reproducible characterization from a clean git clone with a single command
- YAML spec table as the unambiguous source of truth for all acceptance limits
- Per-corner pass/fail evaluation across the full PVT matrix
- Monte Carlo statistical summary for each measured parameter
- Self-contained HTML report usable as a datasheet substitute
- Reusable pipeline structure applicable to future analog blocks (opamp, reference)

**Non-Goals:**
- StrongARM / dynamic latch comparator topology (v2)
- Post-layout (extracted netlist) characterization
- Xyce or Spectre simulator support
- GF180MCU or any non-SKY130 PDK
- CACE YAML compatibility
- Auto-sizing or specification-driven topology generation
- PDF report generation
- Tapeout-ready LVS/DRC-clean layout

## Decisions

### Decision 1: Hybrid Makefile + ngspice + Python
- **Chosen**: Makefile as top-level entry point; Bash scripts for sweep orchestration; Python only for post-processing
- **Rationale**: Makefile targets are independently runnable, inspectable, and CI-friendly without Python in the critical path. Each stage's inputs and outputs are explicit files — no hidden state. The primary user (analog IC designer) is more likely to trust and debug a Makefile than a Python orchestration framework.
- **Alternative considered**: Python + spicelib SimRunner for end-to-end orchestration — viable but adds Python as a dependency for running simulations, not just post-processing. Adds abstraction between the designer and what ngspice is actually doing.

### Decision 2: YAML spec table
- **Chosen**: YAML as spec source of truth
- **Rationale**: Machine-readable (Python validation and report header generation), human-readable in a text editor, version-controllable with meaningful diffs. Simpler schema than CACE YAML — one file, flat list of parameter entries.
- **Alternative considered**: Markdown table — maximum readability but not parseable without custom parsing. CSV — parseable but poor human readability and no support for inline comments or nested fields.

### Decision 3: Static differential-pair comparator topology
- **Chosen**: Static differential-pair for v1
- **Rationale**: Simpler DC operating point, easier to characterize (no clock, no regeneration phase), better as a methodology teaching example. The testbench harnesses and sweep scripts are the primary deliverable — a topology that is straightforward to measure keeps focus on methodology clarity.
- **Alternative considered**: StrongARM dynamic latch — better performance (zero static power, faster), but clocked operation complicates propagation delay and offset measurement. Reserved for v2.

### Decision 4: spicelib for raw file parsing
- **Chosen**: `spicelib` (PyPI)
- **Rationale**: Actively maintained, handles ngspice `.raw` binary and ASCII formats, provides `RawRead` and `SimRunner` APIs. Avoids writing a custom raw file parser.
- **Alternative considered**: PySpice — in maintenance mode since 2020, SKY130 integration undocumented, rejected. Custom parser — viable but unnecessary given spicelib exists.

## Risks / Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| SKY130 corner model incompatibility across ngspice versions | Medium | High | Pin ngspice ≥38; validate-corners script catches model loading failures before sweep |
| PDK path fragility (volare vs open_pdks directory layouts differ) | High | High | Use `PDK_ROOT` env var as sole reference; provide detection script; test against both |
| ngspice MC model reliability (mismatch params behave differently across versions) | Medium | Medium | Document MC model source; include reference MC run with expected mean/σ; sanity-check script |
| Efabless/SKY130 shuttle continuity (reduced tapeout access post-Efabless) | Medium | Medium | Methodology is PDK-agnostic; corner scripts parameterizable for GF180MCU |
| Low community adoption ("yet another characterization tool") | Medium | Medium | Emphasize methodology over tooling; target SSCS PICO and Tiny Tapeout communities; publish worked example report as showcase |
| Scope creep to opamp/reference before comparator is solid | High | Medium | Strict v1 scope gate: opamp/reference work begins only after comparator report is published |
| ngspice performance for large sweeps (30 corners × 200 MC = 6,000 runs) | Medium | Low | Shell process pool for parallelization; document expected runtimes; provide fast-mode Makefile targets |

## Testing Strategy

| Level | What is tested | When |
|-------|---------------|------|
| **Unit** | Metric extraction scripts: given a known ngspice `.raw` file, assert correct scalar value extracted; YAML spec schema validation | Per commit to `scripts/` or `specs/` |
| **Integration** | `make corners` on a minimal testbench (TT/27°C/1.8V only): assert output file produced and metric extracted correctly | Per commit to `tb/` or `scripts/` |
| **End-to-end** | `make characterize` on a clean checkout: assert `reports/characterization_report.html` is produced and contains expected pass/fail verdicts for known corners | Before tagging a release |
| **Reproducibility** | Two independent runs of `make characterize` from the same git SHA produce byte-identical `summary.csv` | Before tagging a release |
