#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

for fn in \
	resolve_packages_source_flavor \
	apply_lean_package_overrides \
	apply_VIKINGYFY_package_overrides \
	apply_generic_package_overrides \
	apply_luci_feed_25_12_package_overrides \
	find_adguardhome_package_dir \
	package_has_adguardhome_translation_zh \
	fallback_adguardhome_package_25_12; do
    grep -q "^${fn}() {" "$TARGET_SCRIPT"
done

extract_function_body() {
	local fn="$1"

	awk -v name="$fn" '
		$0 ~ "^" name "\\(\\) \\{" { in_fn=1; next }
		in_fn && /^}/ { exit }
		in_fn { print }
	' "$TARGET_SCRIPT"
}

extract_function_body "apply_VIKINGYFY_package_overrides" | grep -q 'update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"'
extract_function_body "apply_generic_package_overrides" | grep -q 'update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"'
extract_function_body "apply_common_package_overrides" | grep -q 'UPDATE_PACKAGE "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "master"'
extract_function_body "apply_common_package_overrides" | grep -q 'update_package_list "luci-app-vlmcsd vlmcsd" "sbwml/openwrt_pkgs" "main"'
extract_function_body "apply_common_package_overrides" | grep -q 'update_package_list "luci-app-socat" "sbwml/openwrt_pkgs" "main"'
extract_function_body "apply_luci_feed_25_12_package_overrides" | grep -q 'is_luci_feed_25_12'
extract_function_body "apply_luci_feed_25_12_package_overrides" | grep -q 'update_package_list "luci-app-accesscontrol" "coolsnowwolf/luci" "openwrt-23.05"'
extract_function_body "package_has_adguardhome_translation_zh" | grep -q 'zh_Hans/adguardhome.po'
extract_function_body "package_has_adguardhome_translation_zh" | grep -q 'zh/adguardhome.po'
extract_function_body "fallback_adguardhome_package_25_12" | grep -q 'package_has_adguardhome_translation_zh'
extract_function_body "fallback_adguardhome_package_25_12" | grep -q 'UPDATE_PACKAGE "luci-app-adguardhome" "xptsp/luci-app-adguardhome" "main"'
grep -q 'find "./${list_repo}" -mindepth 1 -maxdepth 2 -type d -iname "${package_name}" -print | head -n 1' "$TARGET_SCRIPT"
if grep -q '^ensure_vlmcsd_ini() {' "$TARGET_SCRIPT"; then
	echo "Packages.sh should no longer carry the legacy ensure_vlmcsd_ini hook" >&2
	exit 1
fi

echo "test_packages_source_flavor: ok"
