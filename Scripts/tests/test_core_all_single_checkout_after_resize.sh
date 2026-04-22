#!/bin/bash

set -eu

python3 - <<'PY'
from pathlib import Path
import sys

workflow_path = Path(".github/workflows/CORE-ALL.yml")
lines = workflow_path.read_text().splitlines()

disk_prepare_line = None
checkout_lines = []

for idx, line in enumerate(lines, start=1):
    if "uses: sbwml/actions@free-disk" in line:
        disk_prepare_line = idx
    if "uses: actions/checkout@" in line:
        checkout_lines.append(idx)

if disk_prepare_line is None:
    print("free-disk step not found", file=sys.stderr)
    sys.exit(1)

if len(checkout_lines) != 1:
    print(
        f"CORE-ALL.yml should have exactly one checkout step, found {len(checkout_lines)}",
        file=sys.stderr,
    )
    sys.exit(1)

if checkout_lines[0] <= disk_prepare_line:
    print(
        "CORE-ALL.yml checkout step should appear after free-disk",
        file=sys.stderr,
    )
    sys.exit(1)

print("test_core_all_single_checkout_after_resize: ok")
PY
