#!/bin/bash

# 说明：CUSTOM 应直接调用 CORE-ALL，让 GitHub Actions 摘要图显示为
# “外层设备 job / 内层设备 job”，与 V-OpenWRT-CI 的 CUSTOM 图形摘要一致。

set -euo pipefail

custom_workflow=".github/workflows/CUSTOM.yml"
core_workflow=".github/workflows/CORE-ALL.yml"

assert_contains() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "$custom_workflow" 'uses: ./.github/workflows/CORE-ALL.yml' "CUSTOM should call CORE-ALL directly for a flat graph"
assert_not_contains "$custom_workflow" 'uses: ./.github/workflows/DEFAULT.yml' "CUSTOM should not add the DEFAULT wrapper layer"

assert_contains "$custom_workflow" 'name: CMIOT-AX18-NOWIFI-fw3-base' "CUSTOM AX18 base job should have a device-first display name"
assert_contains "$custom_workflow" 'name: CMIOT-AX18-NOWIFI-fw3-frps' "CUSTOM AX18 frps job should have a device-first display name"
assert_contains "$custom_workflow" 'name: GL-MT6000-WIFI-fw3-base' "CUSTOM MT6000 job should have a device-first display name"
assert_contains "$custom_workflow" 'name: JD-AX6600-WIFI-fw3-base' "CUSTOM JD AX6600 job should have a device-first display name"
assert_not_contains "$custom_workflow" 'name: lean-' "CUSTOM graph labels should not be prefixed with lean"

assert_contains "$custom_workflow" 'WRT_SOURCE_HASH_INFO:' "CUSTOM should expose the optional source hash input"
assert_contains "$custom_workflow" 'WRT_SOURCE_HASH_INFO: ${{ inputs.WRT_SOURCE_HASH_INFO }}' "CUSTOM should pass source hash input when calling CORE-ALL"
assert_contains "$custom_workflow" 'WRT_DIY_FEEDS: diy_feeds.sh' "CUSTOM should pass the default feeds script when calling CORE-ALL"
assert_contains "$custom_workflow" 'WRT_MINE_SAY: ${{ inputs.WHAT_MY_SAY }}' "CUSTOM should map the note input to CORE-ALL"
assert_not_contains "$custom_workflow" '      WHAT_MY_SAY: ${{ inputs.WHAT_MY_SAY }}' "CUSTOM should not pass DEFAULT-only input names to CORE-ALL"

assert_contains "$core_workflow" 'name: ${{ inputs.WRT_DEVICE }}-${{ inputs.WRT_FIREWALL }}-${{ inputs.WRT_OVERLAYS != '"'"''"'"' && inputs.WRT_OVERLAYS || '"'"'base'"'"' }}' "CORE-ALL build job should expose a device-first reusable job name"

echo "test_custom_workflow_graph: ok"
