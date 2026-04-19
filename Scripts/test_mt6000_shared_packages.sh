#!/bin/bash

# 说明：MT6000-WIFI 的一组设备共用包不区分 FW3/FW4，
# 应统一由 devices/MT6000-WIFI.txt 提供，而不是分别散落在 device-overlays。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW3_OUT="$TMPDIR/fw3.txt"
FW4_OUT="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "MT6000-WIFI" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "MT6000-WIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

for output in "$FW3_OUT" "$FW4_OUT"; do
	grep -n '^CONFIG_PACKAGE_luci-app-openclash=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openclash=y'
	grep -n '^CONFIG_PACKAGE_luci-app-wrtbwmon=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wrtbwmon=y'
	grep -n '^CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn=y'
	grep -n '^CONFIG_PACKAGE_wrtbwmon=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wrtbwmon=y'
	grep -n '^CONFIG_PACKAGE_luci-app-openlist=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openlist=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=m'
done

echo "test_mt6000_shared_packages: ok"
