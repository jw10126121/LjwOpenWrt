#!/bin/bash

# 说明：CMIOT-AX18-NOWIFI 的一组设备共用包与 FW3 设备差异
# 已统一收口到 Config/CMIOT-AX18-NOWIFI-FW3.txt，不再拆成普通设备层 + device-overlays。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
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
	--device "CMIOT-AX18-NOWIFI" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "CMIOT-AX18-NOWIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

for output in "$FW3_OUT" "$FW4_OUT"; do
	grep -n '^CONFIG_PACKAGE_luci-app-openclash=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openclash=[ym]'
	grep -n '^CONFIG_PACKAGE_luci-app-wrtbwmon=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wrtbwmon=[ym]'
	grep -n '^CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn=[ym]'
	grep -n '^CONFIG_PACKAGE_wrtbwmon=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wrtbwmon=[ym]'
	grep -n '^CONFIG_PACKAGE_luci-app-openlist=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openlist=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=m'
done

echo "test_cmiot_ax18_shared_packages: ok"
