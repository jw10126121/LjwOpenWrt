#!/bin/bash

# 说明：验证 WRT_LUCI_BRANCH 已贯通到 DEFAULT / CORE-ALL / main，
# 并且 CUSTOM-LUCI2305 预设显式使用 openwrt-23.05。

set -euo pipefail

default_workflow=".github/workflows/DEFAULT.yml"
core_workflow=".github/workflows/CORE-ALL.yml"
custom_luci_workflow=".github/workflows/CUSTOM-LUCI2305.yml"

assert_contains() {
	local file_path=$1
	local pattern=$2
	local message=$3

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "$default_workflow" "WRT_LUCI_BRANCH:" "DEFAULT should expose WRT_LUCI_BRANCH"
assert_contains "$default_workflow" 'WRT_LUCI_BRANCH: ${{ inputs.WRT_LUCI_BRANCH }}' "DEFAULT should pass WRT_LUCI_BRANCH to CORE-ALL"

assert_contains "$core_workflow" "WRT_LUCI_BRANCH:" "CORE-ALL should accept WRT_LUCI_BRANCH"
assert_contains "$core_workflow" 'WRT_LUCI_BRANCH: ${{inputs.WRT_LUCI_BRANCH || ' "CORE-ALL should export WRT_LUCI_BRANCH into env"

assert_contains "$custom_luci_workflow" "WRT_LUCI_BRANCH: openwrt-23.05" "CUSTOM-LUCI2305 should pin LuCI branch to openwrt-23.05"
assert_contains "$custom_luci_workflow" "# WRT_SOURCE_HASH_INFO: ecec1ef93a8920f30ef927d989b13b674d614ca6" "CUSTOM-LUCI2305 should keep the old hash as a comment for later reuse"
if grep -Fq 'luci23' "$default_workflow"; then
	echo "DEFAULT should no longer mention luci23 overlay compatibility" >&2
	exit 1
fi
if grep -Eq '^[[:space:]]*WRT_SOURCE_HASH_INFO:[[:space:]]+ecec1ef93a8920f30ef927d989b13b674d614ca6' "$custom_luci_workflow"; then
	echo "CUSTOM-LUCI2305 should not actively pin the old hash anymore" >&2
	exit 1
fi

echo "test_workflow_luci_branch_input: ok"
