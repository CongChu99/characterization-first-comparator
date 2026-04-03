# Tech Stack: Characterization-First Comparator / Reference / Opamp Block

## EDA / Simulation

- **Schematic entry**: xschem (open-source, SKY130 symbol library available via open_pdks)
- **Simulator**: ngspice ≥38 (batch mode via `ngspice -b`; `.control` scripting for sweeps and MC)
- **PDK**: SkyWater SKY130 (`sky130A`) — installed via `volare` (recommended) or `open_pdks`. Referenced via `PDK_ROOT` environment variable.
- **Rationale**: Only viable open-source stack with full SKY130 support. No alternatives considered for v1.

## Automation Layer

- **Build orchestration**: GNU Make — top-level entry point (`make characterize`, `make corners`, `make mc`, `make report`)
- **Simulation orchestration**: Bash shell scripts — generate per-corner ngspice input files, invoke `ngspice -b`, collect outputs into `results/`
- **Alternative considered**: Python-only orchestration (spicelib SimRunner) — rejected for v1 in favor of explicit Makefile targets that are inspectable and CI-friendly without Python dependency at the orchestration layer

## Post-Processing / Metric Extraction

- **Language**: Python ≥3.10
- **SPICE output parsing**: `spicelib` (PyPI: `spicelib`) — raw file reader (`RawRead`) for ngspice `.raw` output; `SpiceEditor` for netlist manipulation if needed
- **Data handling**: `pandas` — assembles per-corner metric tables
- **Alternatives considered**: Direct raw file parsing without spicelib — viable but more work; PySpice — in maintenance mode, rejected

## Report Generation

- **Templating**: `Jinja2` — renders HTML characterization report from spec table + results data
- **Plotting**: `matplotlib` — MC histograms, corner sweep bar charts embedded in report
- **Output formats**: HTML (primary), Markdown (secondary/fallback)
- **Results format**: JSON (machine-readable, per-corner metrics), CSV (spreadsheet-friendly summary)

## Version Control & Reproducibility

- **VCS**: Git — all design files, testbenches, scripts, and results committed
- **PDK versioning**: `volare` for pinned SKY130 PDK version
- **Dependency management**: `requirements.txt` (Python deps); README documents exact ngspice version

## CI/CD

- **Pipeline**: GitHub Actions — runs `make characterize` on push; publishes report as artifact
- **Status**: Stretch goal (P2) — not required for v1

## Skipped Categories

- **Frontend**: N/A — no web UI; report is static HTML/Markdown
- **Database**: N/A — results stored as JSON/CSV files in `results/`
- **Cloud infrastructure**: N/A — fully local execution
- **Monitoring/APM**: N/A
