#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"

count=$(grep -c 'bash "\$GITHUB_WORKSPACE/\$WRT_DIR_SCRIPTS/export_config.sh"' "$workflow_file")
[ "$count" -eq 1 ] || {
	echo "CORE-ALL should call export_config.sh only once" >&2
	exit 1
}

grep -Fq 'cp -f ./.config ./base_config.txt' "$workflow_file" || {
	echo "CORE-ALL should persist the prepared base config after the initial export" >&2
	exit 1
}

grep -Fq 'cp -f ./base_config.txt ./.config' "$workflow_file" || {
	echo "CORE-ALL should restore .config from the prepared base config before diy settings" >&2
	exit 1
}

echo "test_core_all_base_config_reuse: ok"
