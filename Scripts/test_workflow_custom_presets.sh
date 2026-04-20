#!/bin/bash

# 说明：CUSTOM 应作为固定预设入口，并行调用 4 个 DEFAULT 工作流。

set -euo pipefail

default_workflow=".github/workflows/DEFAULT.yml"
custom_workflow=".github/workflows/CUSTOM.yml"

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

assert_not_contains_before_jobs() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if awk '/^jobs:/{exit} {print}' "$file_path" | grep -Fq "$pattern"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern before jobs: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "$default_workflow" "workflow_dispatch:" "DEFAULT should still support manual runs"
assert_contains "$default_workflow" "workflow_call:" "DEFAULT should be reusable from CUSTOM"
assert_contains "$default_workflow" "WRT_OVERLAYS:" "DEFAULT reusable workflow should expose overlays input"
assert_contains "$default_workflow" "IPQ60XX-NOWIFI-MINI" "DEFAULT should expose IPQ MINI in manual choices"
assert_contains "$default_workflow" "MT6000-WIFI-MINI" "DEFAULT should expose MT6000 MINI in manual choices"

assert_not_contains_before_jobs "$custom_workflow" "WRT_DEVICE:" "CUSTOM should no longer expose per-run device input"
assert_not_contains_before_jobs "$custom_workflow" "WRT_SOURCE_FLAVOR:" "CUSTOM should no longer expose per-run source flavor input"

assert_contains "$custom_workflow" "uses: ./.github/workflows/DEFAULT.yml" "CUSTOM should call DEFAULT reusable workflow"
assert_contains "$custom_workflow" "secrets: inherit" "CUSTOM should inherit secrets when calling DEFAULT"

assert_contains "$custom_workflow" "ipq60xx_nowifi_fw3:" "CUSTOM should include IPQ60XX fw3 preset"
assert_contains "$custom_workflow" "WRT_DEVICE: IPQ60XX-NOWIFI" "IPQ60XX preset should pass the correct device"
assert_contains "$custom_workflow" "WRT_FIREWALL: fw3" "fw3 preset should be present"
assert_contains "$custom_workflow" "WRT_RELEASE_FIRMWARE: true" "firmware release preset should be enabled where requested"
assert_contains "$custom_workflow" "WRT_SOURCE_FLAVOR: lean" "lean source preset should be present"

assert_contains "$custom_workflow" "ipq60xx_nowifi_mini_fw3:" "CUSTOM should include IPQ60XX MINI fw3 preset"
assert_contains "$custom_workflow" "WRT_DEVICE: IPQ60XX-NOWIFI-MINI" "IPQ60XX MINI preset should pass the correct device"

assert_contains "$custom_workflow" "ipq60xx_nowifi_fw3_frps:" "CUSTOM should include IPQ60XX frps preset"
assert_contains "$custom_workflow" "WRT_OVERLAYS: frps" "frps preset should pass overlays"

assert_contains "$custom_workflow" "ipq60xx_nowifi_mini_fw3_frps:" "CUSTOM should include IPQ60XX MINI frps preset"

assert_contains "$custom_workflow" "mt6000_wifi_fw3:" "CUSTOM should include MT6000 fw3 preset"
assert_contains "$custom_workflow" "WRT_DEVICE: MT6000-WIFI" "MT6000 preset should pass the correct device"

assert_contains "$custom_workflow" "mt6000_wifi_mini_fw3:" "CUSTOM should include MT6000 MINI fw3 preset"
assert_contains "$custom_workflow" "WRT_DEVICE: MT6000-WIFI-MINI" "MT6000 MINI preset should pass the correct device"

assert_contains "$custom_workflow" "ipq60xx_nowifi_mini_fw4_vikingyfy:" "CUSTOM should include IPQ60XX MINI fw4 VIKINGYFY preset"

assert_contains "$custom_workflow" "mt6000_wifi_fw4_vikingyfy:" "CUSTOM should include MT6000 fw4 VIKINGYFY preset"
assert_contains "$custom_workflow" "WRT_FIREWALL: fw4" "fw4 preset should be present"
assert_contains "$custom_workflow" "WRT_RELEASE_FIRMWARE: false" "MT6000 fw4 preset should disable release"
assert_contains "$custom_workflow" "WRT_SOURCE_FLAVOR: VIKINGYFY" "VIKINGYFY preset should be present"

assert_contains "$custom_workflow" "mt6000_wifi_mini_fw4_vikingyfy:" "CUSTOM should include MT6000 MINI fw4 VIKINGYFY preset"

echo "test_workflow_custom_presets: ok"
