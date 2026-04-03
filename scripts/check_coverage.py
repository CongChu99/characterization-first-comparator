#!/usr/bin/env python3
"""
scripts/check_coverage.py
Verifies that every parameter in comparator_spec.yaml has an existing testbench file.
Exit 0 = all covered, Exit 1 = missing testbenches found.
"""
import sys
from pathlib import Path
import yaml


def main() -> int:
    spec_path = Path("specs/comparator_spec.yaml")
    if not spec_path.exists():
        print(f"[check-coverage] ERROR: spec not found: {spec_path}", file=sys.stderr)
        return 1

    with spec_path.open() as f:
        spec = yaml.safe_load(f)

    params = spec.get("parameters", [])
    missing = []

    for p in params:
        tb = p.get("testbench", "")
        if tb and not Path(tb).exists():
            missing.append(f"  {p['name']}: {tb}")

    unique_tbs = len(set(p.get("testbench", "") for p in params if p.get("testbench")))

    if missing:
        print(f"[check-coverage] FAIL — {len(missing)} missing testbench(es):")
        for m in missing:
            print(m)
        return 1
    else:
        print(f"[check-coverage] PASS — all {len(params)} parameters covered "
              f"({unique_tbs} testbench files found)")
        return 0


if __name__ == "__main__":
    sys.exit(main())
