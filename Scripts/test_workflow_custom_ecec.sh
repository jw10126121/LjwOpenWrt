#!/bin/bash

# 说明：CUSTOM-ECEC 应复用 CUSTOM 的 preset 结构，但固定到指定 lean commit。

set -euo pipefail

workflow=".github/workflows/CUSTOM-ECEC.yml"
target_hash="ecec1ef93a8920f30ef927d989b13b674d614ca6"

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

test -f "$workflow"

assert_contains "$workflow" "name: CUSTOM-ECEC" "CUSTOM-ECEC should expose a distinct workflow name"
assert_contains "$workflow" "uses: ./.github/workflows/DEFAULT.yml" "CUSTOM-ECEC should reuse DEFAULT workflow"
assert_contains "$workflow" "WRT_SOURCE_FLAVOR: lean" "CUSTOM-ECEC should stay on lean source flavor"
assert_contains "$workflow" "WRT_SOURCE_HASH_INFO: ${target_hash}" "CUSTOM-ECEC should pin the requested lean commit"

assert_contains "$workflow" "ipq60xx_nowifi_fw3:" "CUSTOM-ECEC should include IPQ60XX fw3 preset"
assert_contains "$workflow" "ipq60xx_nowifi_fw3_frps:" "CUSTOM-ECEC should include IPQ60XX frps preset"
assert_contains "$workflow" "mt6000_wifi_fw3:" "CUSTOM-ECEC should include MT6000 fw3 preset"

echo "test_workflow_custom_ecec: ok"
