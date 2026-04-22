#!/bin/bash

# 说明：lean 成为唯一源码后，外部 workflow 不再暴露源码风味输入，
# 也不再直接暴露 repo_url / branch。

set -eu

WORKFLOWS_WITHOUT_SOURCE_FLAVOR_INPUT=(
	".github/workflows/main.yml"
	".github/workflows/DEFAULT.yml"
	".github/workflows/CORE-ALL.yml"
	".github/workflows/TEST-METADATA.yml"
)

for workflow in "${WORKFLOWS_WITHOUT_SOURCE_FLAVOR_INPUT[@]}"; do
	if grep -q 'WRT_SOURCE_FLAVOR:' "$workflow"; then
		echo "$workflow should not expose or consume WRT_SOURCE_FLAVOR anymore" >&2
		exit 1
	fi
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
