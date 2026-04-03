#!/usr/bin/env python3
"""validate_spec.py — validate comparator_spec.yaml against the required schema.

Usage:
    python3 scripts/validate_spec.py <yaml_file>

Exit codes:
    0  — all parameters are valid
    1  — validation error or file not found
"""

import sys

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

REQUIRED_FIELDS = [
    "name",
    "description",
    "units",
    "min",
    "typ",
    "max",
    "condition",
    "measurement_method",
    "testbench",
]

# Fields that are allowed to be None (null in YAML)
NULLABLE_FIELDS = {"min", "typ", "max"}


def validate(yaml_file: str) -> int:
    """Load and validate the spec file.  Returns 0 on success, 1 on failure."""
    try:
        with open(yaml_file, "r") as fh:
            data = yaml.safe_load(fh)
    except FileNotFoundError:
        print(f"ERROR: file not found: {yaml_file}", file=sys.stderr)
        return 1
    except yaml.YAMLError as exc:
        print(f"ERROR: could not parse YAML: {exc}", file=sys.stderr)
        return 1

    if not isinstance(data, dict) or "parameters" not in data:
        print("ERROR: YAML must contain a top-level 'parameters' key", file=sys.stderr)
        return 1

    parameters = data["parameters"]
    if not isinstance(parameters, list):
        print("ERROR: 'parameters' must be a list", file=sys.stderr)
        return 1

    errors_found = False

    for param in parameters:
        if not isinstance(param, dict):
            print("ERROR: each parameter must be a YAML mapping", file=sys.stderr)
            errors_found = True
            continue

        # Use the name for reporting if available, otherwise a placeholder
        param_name = param.get("name", "<unnamed>")

        for field in REQUIRED_FIELDS:
            if field not in param:
                # Field is entirely absent from the mapping
                print(
                    f"ERROR: parameter '{param_name}' missing field '{field}'",
                    file=sys.stderr,
                )
                errors_found = True
            elif param[field] is None and field not in NULLABLE_FIELDS:
                # Non-nullable field is explicitly set to null
                print(
                    f"ERROR: parameter '{param_name}' field '{field}' must not be null",
                    file=sys.stderr,
                )
                errors_found = True

    if errors_found:
        return 1

    count = len(parameters)
    print(f"OK: {count} parameter{'s' if count != 1 else ''} validated")
    return 0


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Usage: python3 {sys.argv[0]} <yaml_file>", file=sys.stderr)
        sys.exit(1)

    sys.exit(validate(sys.argv[1]))


if __name__ == "__main__":
    main()
