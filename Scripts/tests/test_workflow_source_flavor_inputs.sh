#!/bin/bash

# 说明：lean 成为唯一源码后，外部 workflow 不再暴露源码风味输入，
# 也不再直接暴露 repo_url / branch。

set -eu

WORKFLOWS_WITHOUT_SOURCE_FLAVOR_INPUT=(
	".github/workflows/DEFAULT.yml"
	".github/workflows/CORE-ALL.yml"
	".github/workflows/TEST-METADATA.yml"
)

for workflow in "${WORKFLOWS_WITHOUT_SOURCE_FLAVOR_INPUT[@]}"; do
	if grep -q 'WRT_SOURCE_FLAVOR:' "$workflow"; then
		echo "$workflow should not expose or consume WRT_SOURCE_FLAVOR anymore" >&2
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
	if grep -q 'WRT_REPO_Commit_Hash' "$workflow"; then
		echo "$workflow should no longer keep the legacy WRT_REPO_Commit_Hash name" >&2
		exit 1
	fi
done

if [ -f ".github/workflows/main.yml" ]; then
	echo ".github/workflows/main.yml should be removed as a legacy workflow" >&2
	exit 1
fi

echo "test_workflow_source_flavor_inputs: ok"
