#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"

for placeholder in \
	"DEVICE_TARGET: ''" \
	"DEVICE_SUBTARGET: ''" \
	"DEVICE_PROFILE: ''" \
	"DEVICE_NAME_LIST: ''" \
	"DEVICE_NAME_LIST_LIAN: ''" \
	"DEVICE_ARCH: ''" \
	"REPO_GIT_HASH: ''" \
	"REPO_GIT_hash_simple: ''"
do
	if grep -Fq -- "$placeholder" "$workflow_file"; then
		echo "CORE-ALL should not keep empty env placeholder: $placeholder" >&2
		exit 1
	fi
done

if grep -q 'echo "name_config_file=' "$workflow_file"; then
	echo "CORE-ALL should not export name_config_file when it is only used locally" >&2
	exit 1
fi

if grep -q '^        release_name=' "$workflow_file"; then
	echo "CORE-ALL should not duplicate release_name when it matches release_tag" >&2
	exit 1
fi

grep -Fq 'release_tag="${{ env.START_TIME }}_${{ env.DEVICE_SUBTARGET }}_${{ env.DEVICE_NAME_LIST_LIAN }}_${{ env.BUILD_VARIANT_TAG }}"' "$workflow_file" || {
	echo "CORE-ALL should still derive a single release_tag identifier" >&2
	exit 1
}

grep -Fq -- '--title "${release_tag}"' "$workflow_file" || {
	echo "CORE-ALL should reuse release_tag as the release title" >&2
	exit 1
}

echo "test_core_all_naming_cleanup: ok"
