#!/bin/bash

# 说明：CUSTOM-APK 应作为固定预设入口，并行调用 4 个 DEFAULT 工作流，
# 仅在 CUSTOM 的 4 个组合上追加 apk overlay。

set -euo pipefail

default_workflow=".github/workflows/DEFAULT.yml"
custom_apk_workflow=".github/workflows/CUSTOM-APK.yml"

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

assert_contains "$default_workflow" "workflow_call:" "DEFAULT should be reusable from CUSTOM-APK"
assert_contains "$default_workflow" "WRT_OVERLAYS:" "DEFAULT reusable workflow should expose overlays input"
assert_contains "$default_workflow" "WRT_LUCI_BRANCH:" "DEFAULT reusable workflow should expose LuCI branch input"
assert_contains "$default_workflow" "IPQ60XX-NOWIFI-MINI" "DEFAULT should expose IPQ MINI in manual choices"
assert_contains "$default_workflow" "MT6000-WIFI-MINI" "DEFAULT should expose MT6000 MINI in manual choices"

assert_not_contains_before_jobs "$custom_apk_workflow" "WRT_DEVICE:" "CUSTOM-APK should not expose per-run device input"
assert_not_contains_before_jobs "$custom_apk_workflow" "WRT_SOURCE_FLAVOR:" "CUSTOM-APK should not expose per-run source flavor input"

assert_contains "$custom_apk_workflow" "uses: ./.github/workflows/DEFAULT.yml" "CUSTOM-APK should call DEFAULT reusable workflow"
assert_contains "$custom_apk_workflow" "secrets: inherit" "CUSTOM-APK should inherit secrets when calling DEFAULT"

assert_contains "$custom_apk_workflow" "ipq60xx_nowifi_fw3_apk:" "CUSTOM-APK should include IPQ60XX fw3 apk preset"
assert_contains "$custom_apk_workflow" "name: lean-IPQ60XX-NOWIFI-fw3-apk" "IPQ60XX apk preset should have a stable display name"
assert_contains "$custom_apk_workflow" "WRT_OVERLAYS: apk" "base apk preset should pass apk overlay"

assert_contains "$custom_apk_workflow" "ipq60xx_nowifi_mini_fw3_apk:" "CUSTOM-APK should include IPQ60XX MINI fw3 apk preset"
assert_contains "$custom_apk_workflow" "name: lean-IPQ60XX-NOWIFI-MINI-fw3-apk" "IPQ60XX MINI apk preset should have a stable display name"

assert_contains "$custom_apk_workflow" "ipq60xx_nowifi_fw3_frps_apk:" "CUSTOM-APK should include IPQ60XX frps apk preset"
assert_contains "$custom_apk_workflow" "name: lean-IPQ60XX-NOWIFI-fw3-frps-apk" "IPQ60XX frps apk preset should have a stable display name"
assert_contains "$custom_apk_workflow" "WRT_OVERLAYS: frps,apk" "frps apk preset should pass both overlays"

assert_contains "$custom_apk_workflow" "ipq60xx_nowifi_mini_fw3_frps_apk:" "CUSTOM-APK should include IPQ60XX MINI frps apk preset"
assert_contains "$custom_apk_workflow" "name: lean-IPQ60XX-NOWIFI-MINI-fw3-frps-apk" "IPQ60XX MINI frps apk preset should have a stable display name"

assert_contains "$custom_apk_workflow" "mt6000_wifi_fw3_apk:" "CUSTOM-APK should include MT6000 fw3 apk preset"
assert_contains "$custom_apk_workflow" "name: lean-MT6000-WIFI-fw3-apk" "MT6000 fw3 apk preset should have a stable display name"

assert_contains "$custom_apk_workflow" "mt6000_wifi_mini_fw3_apk:" "CUSTOM-APK should include MT6000 MINI fw3 apk preset"
assert_contains "$custom_apk_workflow" "name: lean-MT6000-WIFI-MINI-fw3-apk" "MT6000 MINI fw3 apk preset should have a stable display name"

echo "test_workflow_custom_apk_presets: ok"
