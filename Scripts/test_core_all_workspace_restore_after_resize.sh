#!/bin/bash

set -eu

python3 - <<'PY'
from pathlib import Path
import sys

workflow_path = Path(".github/workflows/CORE-ALL.yml")
lines = workflow_path.read_text().splitlines()

combine_line = None
checkout_lines = []
repo_reference_lines = []
reference_markers = (
    "Scripts/",
    "Config/",
    "WRT_DIR_SCRIPTS",
    "WRT_DIR_CONFIGS",
    "README.md",
    "readme.txt",
)

for idx, line in enumerate(lines, start=1):
    if "- name: Combine Disks" in line:
        combine_line = idx
    if "uses: actions/checkout@" in line:
        checkout_lines.append(idx)
    if "GITHUB_WORKSPACE" in line and any(marker in line for marker in reference_markers):
        repo_reference_lines.append(idx)

if combine_line is None:
    print("Combine Disks step not found", file=sys.stderr)
    sys.exit(1)

references_after_resize = [line for line in repo_reference_lines if line > combine_line]

if not references_after_resize:
    print("test_core_all_workspace_restore_after_resize: ok")
    sys.exit(0)

checkouts_after_resize = [line for line in checkout_lines if line > combine_line]

if not checkouts_after_resize:
    print(
        "CORE-ALL.yml references repository files after Combine Disks without re-checkout",
        file=sys.stderr,
    )
    sys.exit(1)

for ref_line in references_after_resize:
    if not any(line < ref_line for line in checkouts_after_resize):
        print(
            f"CORE-ALL.yml repo file reference line {ref_line} must have a checkout after Combine Disks",
            file=sys.stderr,
        )
        sys.exit(1)

print("test_core_all_workspace_restore_after_resize: ok")
PY
