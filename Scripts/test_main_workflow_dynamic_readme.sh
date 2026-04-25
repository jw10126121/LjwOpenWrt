#!/bin/bash

set -eu

workflow=".github/workflows/main.yml"

grep -Fq 'export_script="$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/export_config.sh"' "$workflow" || {
	echo "main workflow should generate a config export before composing readme" >&2
	exit 1
}

grep -Fq 'readme_script="$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/readme.sh"' "$workflow" || {
	echo "main workflow should use readme.sh" >&2
	exit 1
}

if grep -Fq '$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/readme.txt' "$workflow"; then
	echo "main workflow should no longer read static Scripts/readme.txt" >&2
	exit 1
fi

echo "test_main_workflow_dynamic_readme: ok"
