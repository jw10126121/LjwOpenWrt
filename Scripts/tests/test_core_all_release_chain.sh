#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"
organize_script="Scripts/ci_organize_outputs.sh"

if grep -q 'VERSION_INFO=' "$workflow_file"; then
	echo "CORE-ALL should not export the unused VERSION_INFO anymore" >&2
	exit 1
fi

if grep -q '^    - name: Prepare Release Body (读取发布内容)$' "$workflow_file"; then
	echo "CORE-ALL should remove the read-only Prepare Release Body step" >&2
	exit 1
fi

grep -Fq -- '--notes-file "${{ env.OPENWRT_PATH }}/readme_release.txt"' "$workflow_file" || {
	echo "CORE-ALL should pass the release notes file directly from OPENWRT_PATH" >&2
	exit 1
}

if grep -q 'echo "release_desc_file=' "$organize_script"; then
	echo "ci_organize_outputs.sh should not export release_desc_file anymore" >&2
	exit 1
fi

if grep -q 'echo "readme_desc_file=' "$organize_script"; then
	echo "ci_organize_outputs.sh should not export readme_desc_file anymore" >&2
	exit 1
fi

echo "test_core_all_release_chain: ok"
