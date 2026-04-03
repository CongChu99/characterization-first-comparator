# Makefile — characterization-first-comparator
# Top-level entry point for the analog characterization pipeline.
#
# Usage:
#   make characterize   — run the full characterization pipeline
#   make clean          — remove generated results/
#
# Required environment variable:
#   PDK_ROOT            — path to the SKY130 PDK root directory
#                         e.g. export PDK_ROOT=/home/user/sky130A

.PHONY: characterize check-pdk-root validate-spec validate-corners check-coverage corners mc extract report clean help

# ---------------------------------------------------------------------------
# PDK_ROOT guard — checked before any simulation target
# ---------------------------------------------------------------------------
check-pdk-root:
	$(if $(PDK_ROOT),,$(error PDK_ROOT is not set. See README for setup instructions.))

# ---------------------------------------------------------------------------
# Top-level characterization target
# Runs the full pipeline in order.
# ---------------------------------------------------------------------------
characterize: check-pdk-root validate-spec validate-corners check-coverage corners mc extract report

# ---------------------------------------------------------------------------
# Stub targets — will be filled by later tasks
# ---------------------------------------------------------------------------
validate-spec:
	python3 scripts/validate_spec.py specs/comparator_spec.yaml

validate-corners: check-pdk-root
	@bash scripts/validate_corners.sh

check-coverage:
	@echo "[check-coverage] Not yet implemented — skipping."

corners: check-pdk-root
	@echo "[corners] Not yet implemented — skipping."

mc: check-pdk-root
	@echo "[mc] Not yet implemented — skipping."

extract: check-pdk-root
	@echo "[extract] Not yet implemented — skipping."

report:
	@echo "[report] Not yet implemented — skipping."

# ---------------------------------------------------------------------------
# Clean — removes results/ only; reports/ is committed and must not be touched
# ---------------------------------------------------------------------------
clean:
	@echo "[clean] Removing results/ ..."
	rm -rf results/
	@echo "[clean] Done. reports/ was not touched."

# ---------------------------------------------------------------------------
# Help — list available targets
# ---------------------------------------------------------------------------
help:
	@echo ""
	@echo "characterization-first-comparator — available make targets"
	@echo ""
	@echo "  make characterize    Run the full PVT + MC characterization pipeline"
	@echo "                       (requires PDK_ROOT to be set)"
	@echo "  make validate-spec   Validate comparator_spec.yaml schema"
	@echo "  make validate-corners Verify SKY130 corner model files are loadable"
	@echo "  make check-coverage  Check testbench coverage against spec parameters"
	@echo "  make corners         Run PVT corner simulations"
	@echo "  make mc              Run Monte Carlo simulations"
	@echo "  make extract         Extract scalar metrics from simulation output"
	@echo "  make report          Generate HTML characterization report"
	@echo "  make clean           Remove results/ (reports/ is preserved)"
	@echo "  make help            Show this message"
	@echo ""
	@echo "Required environment variable:"
	@echo "  PDK_ROOT             Path to SKY130 PDK root (see README)"
	@echo ""
