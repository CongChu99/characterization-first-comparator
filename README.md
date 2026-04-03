# Characterization-First Comparator

> **Characterization-First Design methodology** for a differential-pair comparator on the SKY130 open-source PDK — spec, simulate, and report before taping out.

[![Tests](https://img.shields.io/badge/tests-139%20passing-brightgreen)](#testing)
[![PDK](https://img.shields.io/badge/PDK-SKY130-blue)](https://github.com/google/skywater-pdk)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

---

## Overview

This project demonstrates the **characterization-first** analog design workflow:

1. Write a machine-readable **spec** (`specs/comparator_spec.yaml`) _before_ any simulation
2. Build **testbenches** (`tb/`) for every spec parameter
3. Run a full **PVT + Monte Carlo** sweep automatically (`make characterize`)
4. Produce a **self-contained HTML report** (`reports/characterization_report.html`) that serves as a datasheet substitute

The comparator is a standard SKY130 differential-pair topology. The methodology is designed to be reusable — swap the DUT netlist and spec YAML to characterize any analog block.

---

## Prerequisites

### Required tools

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **ngspice** | ≥ 38 | Circuit simulation engine |
| **Python** | ≥ 3.9 | Metric extraction and report generation |
| **PyYAML** | ≥ 6.0 | Spec file parsing (`pip install pyyaml`) |
| **Jinja2** | ≥ 3.1 | HTML report templating (`pip install jinja2`) |
| **matplotlib** | ≥ 3.5 | MC histogram generation (`pip install matplotlib`) |
| **bc** | any | VDD tag arithmetic in shell scripts |
| **make** | ≥ 3.81 | Build system orchestration |

### Install Python dependencies

```bash
pip install pyyaml jinja2 matplotlib
# or with conda:
conda install -c conda-forge pyyaml jinja2 matplotlib
```

### Install ngspice (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install -y ngspice
ngspice --version   # must be >= 38
```

### Install ngspice from source (recommended for SKY130 compatibility)

```bash
# See: http://ngspice.sourceforge.net/download.html
wget https://sourceforge.net/projects/ngspice/files/ng-spice-rework/38/ngspice-38.tar.gz
tar -xf ngspice-38.tar.gz && cd ngspice-38
./configure --with-x --enable-xspice --enable-cider --with-ngshared
make -j$(nproc) && sudo make install
```

---

## PDK Setup

This project requires the **SKY130A PDK** from Google/SkyWater.

```bash
# Option 1: Use open_pdks (recommended)
git clone https://github.com/RTimothyEdwards/open_pdks
cd open_pdks
./configure --enable-sky130-pdk
make && sudo make install
export PDK_ROOT=/usr/local/share/pdk   # adjust to your install path

# Option 2: Use pre-built PDK from IIC-OSIC-TOOLS
# https://github.com/iic-jku/iic-osic-tools
export PDK_ROOT=/foss/pdks             # inside iic-osic-tools container
```

> **Important:** `PDK_ROOT` must point to the directory containing `sky130A/`.
> The path should resolve: `$PDK_ROOT/sky130A/libs.tech/ngspice/sky130.lib.spice`

Persist the variable in your shell config:

```bash
echo 'export PDK_ROOT=/path/to/your/pdk' >> ~/.bashrc
source ~/.bashrc
```

---

## Project Structure

```
characterization-first-comparator/
├── comparator.spice              # DUT netlist (differential-pair comparator)
├── specs/
│   └── comparator_spec.yaml      # Machine-readable spec (7 parameters)
├── tb/
│   ├── tb_tprop.sp               # Propagation delay testbench
│   ├── tb_idd.sp                 # Quiescent current testbench
│   ├── tb_swing.sp               # Output swing (VOH/VOL) testbench
│   ├── tb_vos.sp                 # Input offset voltage testbench
│   └── tb_vhyst.sp               # Hysteresis testbench
├── scripts/
│   ├── validate_corners.sh       # Corner model file validator
│   ├── validate_spec.py          # Spec YAML schema validator
│   ├── run_corners.sh            # PVT corner sweep orchestrator
│   ├── run_mc.sh                 # Monte Carlo sweep orchestrator
│   ├── extract/
│   │   └── extract_metrics.py    # Simulation log → JSON/CSV parser
│   └── report/
│       ├── generate_report.py    # HTML report generator
│       └── templates/
│           └── report.html.j2    # Jinja2 HTML template
├── results/                      # (generated, git-ignored) simulation output
│   ├── corners/                  # PVT corner raw files
│   ├── mc/                       # Monte Carlo raw files
│   └── extracted/                # Parsed JSON + summary.csv
├── reports/
│   └── characterization_report.html  # Final HTML report (committed)
├── tests/                        # TDD test suites (13 suites, 139 tests)
├── docs/                         # Specs, design notes, c4flow state
└── Makefile                      # Top-level build system
```

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/CongChu99/characterization-first-comparator.git
cd characterization-first-comparator

# 2. Set PDK_ROOT (required for simulation)
export PDK_ROOT=/path/to/your/sky130A/parent/dir

# 3. Run the full characterization pipeline
make characterize

# 4. Open the report
xdg-open reports/characterization_report.html   # Linux
open reports/characterization_report.html        # macOS
```

### Run individual pipeline stages

```bash
make validate-spec      # Validate comparator_spec.yaml schema
make validate-corners   # Verify SKY130 corner model files are loadable
make check-coverage     # Check all spec parameters have testbenches
make corners            # PVT corner sweep (5 corners × 3 temps × 2 VDDs)
make mc                 # Monte Carlo sweep (200 iter × 5 testbenches)
make extract            # Extract scalar metrics → results/extracted/
make report             # Generate HTML report → reports/characterization_report.html
make clean              # Remove results/ (reports/ is preserved)
make help               # Show all available targets
```

---

## Specification

The comparator is characterized against 7 parameters from `specs/comparator_spec.yaml`:

| Parameter | Description | Typ | Max | Units |
|-----------|-------------|-----|-----|-------|
| `t_prop_hl` | Propagation delay (H→L) | 10 | 50 | ns |
| `t_prop_lh` | Propagation delay (L→H) | 10 | 50 | ns |
| `VOS` | Input offset voltage | 0 | 5 | mV |
| `VHYST` | Input hysteresis | 0 | 2 | mV |
| `Idd` | Supply current | 100 | 300 | µA |
| `VOH` | Output high voltage | — | — | V (min 1.6) |
| `VOL` | Output low voltage | — | 0.2 | V |

---

## Methodology

### Characterization-First Workflow

```
Spec YAML  →  Testbenches  →  PVT Sweep  →  Monte Carlo  →  Extract  →  Report
   │               │              │               │              │           │
comparator_  tb_*.sp files   run_corners.sh  run_mc.sh   extract_      generate_
spec.yaml                    (30 corners)    (200 iter)  metrics.py    report.py
```

### PVT Corner Matrix

The sweep covers **30 operating points** per testbench:

- **Process corners** (5): `tt`, `ff`, `ss`, `fs`, `sf`
- **Supply voltages** (2): 1.62 V (−10%), 1.80 V (nom), 1.98 V (+10%)
  - Note: 3 VDD values × 5 corners × 3 temps gives 45 pts; sweep uses 2 VDD × 5 corners × 3 temps = 30 points
- **Temperatures** (3): −40 °C, 27 °C (nom), 125 °C

Corner output is stored as: `results/corners/<param>/<corner>_<vdd>mV_<temp>C/`

### Monte Carlo Analysis

- **200 iterations** per testbench at the nominal corner (TT, 1.80 V, 27 °C)
- Uses SKY130 statistical models: `mc_mm_switch=1` (mismatch) + `mc_pr_switch=1` (process variation)
- Each run uses a unique reproducible seed: `BASE_SEED=42 + run_index`
- Results: `results/mc/<param>/run_NNN.log` + `summary.csv`

### PASS/FAIL Verdict

The report declares **PASS** only when every parameter passes at all measured corners.
Any corner that violates `min` or `max` from `comparator_spec.yaml` marks that corner as **FAIL** and appears in the failure list.

---

## Expected Runtimes

| Stage | Approx. time | Notes |
|-------|-------------|-------|
| `validate-spec` + `validate-corners` | < 1 min | No simulation |
| `make corners` (PVT sweep) | ~5–15 min | 150 ngspice runs, 4 parallel jobs |
| `make mc` (Monte Carlo) | ~20–60 min | 1000 ngspice runs total (200 × 5 TB) |
| `make extract` | < 30 sec | Pure Python log parsing |
| `make report` | ~10–30 sec | Jinja2 + matplotlib |
| **`make characterize` (full)** | **~30–90 min** | Depends on CPU cores and ngspice version |

Control parallelism:
```bash
NGSPICE_JOBS=8 make characterize   # use 8 parallel ngspice processes
```

---

## Testing

The project uses a TDD approach — all deliverables are validated by shell-based test suites that run _without_ ngspice (structural/functional tests using mock data):

```bash
# Run all test suites
for f in tests/test_*.sh; do bash "$f"; done

# Run individual suite
bash tests/test_tb_vos.sh
bash tests/test_run_corners.sh
bash tests/test_extract_metrics.sh
bash tests/test_generate_report.sh
```

| Suite | Tests | Validates |
|-------|-------|-----------|
| `test_netlist.sh` | 7 | DUT netlist structure |
| `test_scaffolding.sh` | 22 | Project directory structure |
| `test_tb_tprop.sh` | 10 | Propagation delay testbench |
| `test_tb_idd.sh` | 10 | Quiescent current testbench |
| `test_tb_swing.sh` | 11 | Output swing testbench |
| `test_tb_vos.sh` | 10 | Input offset testbench |
| `test_tb_vhyst.sh` | 10 | Hysteresis testbench |
| `test_validate_corners.sh` | 10 | Corner model validator |
| `test_validate_spec.sh` | 12 | Spec YAML validator |
| `test_run_corners.sh` | 13 | PVT sweep orchestrator |
| `test_run_mc.sh` | 12 | Monte Carlo orchestrator |
| `test_extract_metrics.sh` | 10 | Metric extraction |
| `test_generate_report.sh` | 12 | HTML report generator |
| `test_integration.sh` | 15 | Full pipeline integration |
| **Total** | **164** | **All deliverables** |

---

## Extending to New Blocks

To characterize a different analog block with this methodology:

1. **Replace the DUT netlist**: edit `comparator.spice` with your subcircuit
2. **Update the spec**: edit `specs/comparator_spec.yaml` with your parameters, limits, and testbench references
3. **Create testbenches**: add `tb/tb_<param>.sp` for each new parameter following the patterns in `tb/tb_vos.sp` or `tb/tb_tprop.sp`
4. **Run**: `make characterize` — the pipeline adapts automatically

---

## Output

After `make characterize`, the primary deliverable is:

```
reports/characterization_report.html
```

A self-contained HTML file (no external dependencies) containing:
- ✅ / ❌ Top-level PASS/FAIL verdict with failure list
- Per-parameter summary cards (color-coded by verdict)
- Per-corner result tables (green = PASS, red = FAIL, grey = no data)
- MC histograms with mean ± 3σ lines and spec limit markers

---

## License

Apache 2.0 — see [LICENSE](LICENSE).
