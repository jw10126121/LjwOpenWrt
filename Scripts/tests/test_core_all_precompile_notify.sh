#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"

if grep -q 'system_content_note<<EOF' "$workflow_file"; then
	echo "CORE-ALL should no longer stash precompile notify content in system_content_note" >&2
	exit 1
fi

if grep -q 'echo "readme_desc_file=' "$workflow_file"; then
	echo "CORE-ALL should not export readme_desc_file before ci_organize_outputs runs" >&2
	exit 1
fi

if grep -Eq '^[[:space:]]*sleep 1$' "$workflow_file"; then
	echo "CORE-ALL should not keep the legacy sleep workaround in Check Config" >&2
	exit 1
fi

grep -Fq 'export DINGDING_MESSAGE="$(cat "$OPENWRT_PATH/config_mine/readme.txt")"' "$workflow_file" || {
	echo "CORE-ALL should export the precompile notify body so python can read DINGDING_MESSAGE" >&2
	exit 1
}

echo "test_core_all_precompile_notify: ok"
