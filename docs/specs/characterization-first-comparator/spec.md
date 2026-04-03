# Spec: Characterization-First Comparator / Reference / Opamp Block

## ADDED Requirements

### Requirement: Spec Table Definition
The project must include a YAML spec table that defines all measured parameters for the comparator before any schematic is drawn. Each parameter entry specifies: name, units, min, typ, max, test condition, and measurement method.

**Priority**: MUST

#### Scenario: Define a propagation delay parameter
- **GIVEN** a new comparator project with no schematic yet
- **WHEN** the designer creates `specs/comparator_spec.yaml` and adds an entry for `t_prop_hl` with min=null, typ=10ns, max=50ns, condition="VDD=1.8V, Vin_step=100mV, T=27°C"
- **THEN** the YAML file is valid against the spec schema and `make validate-spec` passes without errors

#### Scenario: Reject incomplete spec entry
- **GIVEN** a spec YAML with a parameter missing the `units` field
- **WHEN** the designer runs `make validate-spec`
- **THEN** the tool reports a validation error identifying the missing field and the parameter name

---

### Requirement: Spec-First Enforcement
The spec table is the single source of truth for parameter names and limits. No testbench or sweep script may reference a parameter not defined in the spec table. Report generation reads limits directly from the spec YAML.

**Priority**: MUST

#### Scenario: Report generation uses spec table limits
- **GIVEN** a spec table with `VOS` max=5mV and extracted results showing VOS=3mV at TT/27°C/1.8V
- **WHEN** the report generator runs
- **THEN** the report marks VOS at that corner as PASS and displays both the spec limit and the measured value

---

### Requirement: Per-Parameter Testbench
The project must include one standalone ngspice testbench (`.sp` file) for each parameter defined in the spec table. Each testbench must run without modification in ngspice batch mode (`ngspice -b`) and must instantiate the comparator DUT using the SKY130 PDK.

**Priority**: MUST

#### Scenario: Run propagation delay testbench standalone
- **GIVEN** a clean checkout with `PDK_ROOT` set to a valid SKY130 installation
- **WHEN** the designer runs `ngspice -b tb/tb_tprop.sp`
- **THEN** ngspice completes without errors and writes a `.raw` output file to `results/raw/`

#### Scenario: Testbench fails gracefully on missing PDK
- **GIVEN** `PDK_ROOT` is not set or points to an invalid path
- **WHEN** the designer runs `ngspice -b tb/tb_tprop.sp`
- **THEN** ngspice reports a model file not found error (not a silent wrong result)

---

### Requirement: Corner Parameterization
Each testbench must accept process corner, supply voltage, and temperature as parameters injected at runtime (via ngspice `.param` or shell variable substitution), without hardcoding any corner into the testbench source file.

**Priority**: MUST

#### Scenario: Run testbench at a non-default corner
- **GIVEN** the propagation delay testbench
- **WHEN** the sweep script invokes it with corner=`ff`, VDD=1.98V, TEMP=125
- **THEN** ngspice loads the `ff` corner model file and simulates at the specified conditions, writing results tagged with those corner parameters

---

### Requirement: Measured Parameters Coverage
The testbench harness must cover all parameters required by the spec table: propagation delay (t_prop_hl, t_prop_lh), input offset voltage (VOS), hysteresis (VHYST), quiescent current (Idd), output high voltage (VOH), and output low voltage (VOL).

**Priority**: MUST

#### Scenario: Full parameter coverage check
- **GIVEN** a spec table with 7 parameters
- **WHEN** the designer runs `make check-coverage`
- **THEN** the tool confirms that a testbench file exists for each parameter and exits with code 0; any missing testbench is reported by name

---

### Requirement: PVT Corner Sweep
The project must automate ngspice simulation across all 5 process corners (TT, FF, SS, FS, SF) × 3 temperatures (−40°C, 27°C, 125°C) × 2 supply voltages (nominal ±10%) = 30 corner points per parameter. Results must be written to a structured `results/` directory with filenames that encode the corner combination.

**Priority**: MUST

#### Scenario: Run full PVT sweep
- **GIVEN** a clean checkout with `PDK_ROOT` set and all testbenches present
- **WHEN** the designer runs `make corners`
- **THEN** ngspice runs 30 simulations per parameter, writes one output file per corner to `results/corners/<param>/<corner_tag>/`, and logs any failures to `results/corners/failures.log`

#### Scenario: Partial failure does not abort sweep
- **GIVEN** a sweep of 30 corners where one corner simulation crashes (e.g., convergence failure)
- **WHEN** `make corners` runs
- **THEN** the sweep continues for all remaining corners, the failed corner is logged in `failures.log` with the corner tag and error message, and the overall make target exits with a non-zero code

---

### Requirement: Monte Carlo Sweep
The project must run ≥200 Monte Carlo iterations per parameter using SKY130 statistical mismatch models. For each parameter, the sweep must extract mean, σ, min, and max across all runs.

**Priority**: MUST

#### Scenario: Run Monte Carlo sweep
- **GIVEN** a clean checkout with SKY130 MC models available under `PDK_ROOT`
- **WHEN** the designer runs `make mc`
- **THEN** ngspice executes ≥200 iterations per parameter, writes per-run results to `results/mc/<param>/`, and the extraction script produces a summary JSON with `{mean, sigma, min, max, n_runs}` per parameter

#### Scenario: MC model validation before sweep
- **GIVEN** the corner validation script has not been run
- **WHEN** the designer runs `make mc`
- **THEN** the Makefile first runs `make validate-corners`; if validation fails, the MC sweep is aborted with a clear error message

---

### Requirement: Metric Extraction
Python scripts must parse ngspice raw/CSV output files and extract scalar metric values for each parameter at each corner. Extracted results must be written to structured JSON (one file per parameter, keyed by corner tag) and a summary CSV aggregating all parameters and corners.

**Priority**: MUST

#### Scenario: Extract metrics from corner sweep results
- **GIVEN** a completed PVT sweep with 30 output files for `t_prop_hl`
- **WHEN** `make extract` runs (or automatically after `make corners`)
- **THEN** the extraction script produces `results/extracted/t_prop_hl.json` containing one entry per corner with `{corner, vdd, temp, value, units}` and updates `results/summary.csv`

#### Scenario: Extraction handles missing simulation output
- **GIVEN** a corner sweep where 2 of 30 simulations failed and produced no output file
- **WHEN** `make extract` runs
- **THEN** those corners are marked `null` in the JSON output with a logged warning — the script does not crash or silently omit them

---

### Requirement: Pass/Fail Characterization Report
The report generator must combine the spec table (YAML) with extracted metrics (JSON/CSV) and produce an HTML report containing: a per-corner pass/fail table for each parameter, MC histograms, and a top-level PASS/FAIL verdict. The report must be self-contained and readable without running any tool.

**Priority**: MUST

#### Scenario: Generate report after full characterization run
- **GIVEN** a completed `make characterize` with all corners extracted and MC results available
- **WHEN** `make report` runs
- **THEN** `reports/characterization_report.html` is generated showing: spec limits per parameter, measured value per corner with PASS/FAIL highlight, MC mean/σ/min/max, and a top-level PASS or FAIL verdict with failing corners listed

#### Scenario: Report correctly identifies a failing corner
- **GIVEN** extracted results where `t_prop_hl` at SS/−40°C/1.62V = 62ns, exceeding spec max of 50ns
- **WHEN** `make report` runs
- **THEN** that cell is highlighted FAIL, the parameter row shows overall FAIL, and the top-level verdict is FAIL with `t_prop_hl @ SS/-40C/1.62V` listed in the failures summary

---

### Requirement: Single-Command Characterization
A `make characterize` target must run the complete flow — corner validation → PVT sweep → Monte Carlo sweep → metric extraction → report generation — from a clean checkout. The Makefile must check for required tools and `PDK_ROOT` before running any simulation.

**Priority**: MUST

#### Scenario: Full flow from clean checkout
- **GIVEN** a machine with ngspice ≥38, Python ≥3.10, required Python packages, and `PDK_ROOT` set to a valid SKY130 installation
- **WHEN** `make characterize` runs from the repo root on a clean checkout
- **THEN** the full flow completes and `reports/characterization_report.html` is produced with no manual steps required

#### Scenario: Missing dependency is caught early
- **GIVEN** `PDK_ROOT` is unset
- **WHEN** `make characterize` runs
- **THEN** the Makefile prints `PDK_ROOT is not set. See README for setup instructions.` and exits before running any simulation

---

### Requirement: Corner Model Validation
Before any full sweep, a validation script must confirm that SKY130 corner model files load correctly in ngspice by running a minimal DC operating point simulation on a known-good reference circuit for each corner.

**Priority**: SHOULD

#### Scenario: Validate all corners successfully
- **GIVEN** a valid SKY130 installation with all 5 corner model files present
- **WHEN** `make validate-corners` runs
- **THEN** ngspice loads each corner model, runs a DC op-point, and the script prints `[PASS] TT FF SS FS SF — all corners validated` and exits 0

#### Scenario: Detect a misconfigured corner model
- **GIVEN** the `fs` corner model file is missing or has an incorrect path
- **WHEN** `make validate-corners` runs
- **THEN** the script prints `[FAIL] fs — model file not found at <path>` and exits non-zero, preventing the full sweep from running
