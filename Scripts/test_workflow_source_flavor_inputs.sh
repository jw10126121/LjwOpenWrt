#!/bin/bash

# 说明：外部 workflow 输入面只暴露源码风味，不再直接暴露 repo_url / branch。

set -eu

WORKFLOWS=(
	".github/workflows/main.yml"
	".github/workflows/DEFAULT.yml"
	".github/workflows/CUSTOM.yml"
	".github/workflows/CORE-ALL.yml"
	".github/workflows/TEST-METADATA.yml"
)

for workflow in "${WORKFLOWS[@]}"; do
	grep -q 'WRT_SOURCE_FLAVOR:' "$workflow"
	if head -n 120 "$workflow" | grep -q '^[[:space:]]*WRT_REPO_URL:'; then
		echo "$workflow still exposes WRT_REPO_URL input" >&2
		exit 1
	fi
	if head -n 120 "$workflow" | grep -q '^[[:space:]]*WRT_REPO_BRANCH:'; then
		echo "$workflow still exposes WRT_REPO_BRANCH input" >&2
		exit 1
	fi
	if grep -q 'inputs.WRT_REPO_URL' "$workflow"; then
		echo "$workflow still consumes inputs.WRT_REPO_URL" >&2
		exit 1
	fi
	if grep -q 'inputs.WRT_REPO_BRANCH' "$workflow"; then
		echo "$workflow still consumes inputs.WRT_REPO_BRANCH" >&2
		exit 1
	fi
done

echo "test_workflow_source_flavor_inputs: ok"
