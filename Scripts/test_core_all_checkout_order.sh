#!/bin/bash

# 说明：确保所有 workflow 在引用仓库内脚本/配置文件前已 checkout 当前仓库；
# 当前不再要求在 maximize-build-space 之后强制二次 checkout。

set -eu

python3 - <<'PY'
from pathlib import Path
import sys

workflow_dir = Path(".github/workflows")
reference_markers = (
    "Scripts/",
    "Config/",
    "WRT_DIR_SCRIPTS",
    "WRT_DIR_CONFIGS",
    "README.md",
    "readme.txt",
)

errors = []

for workflow_path in sorted(workflow_dir.glob("*.yml")):
    lines = workflow_path.read_text().splitlines()
    checkout_lines = []
    repo_reference_lines = []

    for idx, line in enumerate(lines, start=1):
        if "uses: actions/checkout@" in line:
            checkout_lines.append(idx)

        if "GITHUB_WORKSPACE" in line and any(marker in line for marker in reference_markers):
            repo_reference_lines.append(idx)

    if not repo_reference_lines:
        continue

    if not checkout_lines:
        errors.append(f"{workflow_path}: missing checkout step")
        continue

    for ref_line in repo_reference_lines:
        valid_checkouts = [line for line in checkout_lines if line < ref_line]
        if not valid_checkouts:
            errors.append(
                f"{workflow_path}: repo file reference line {ref_line} must have a prior checkout step"
            )

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

print("test_core_all_checkout_order: ok")
PY
