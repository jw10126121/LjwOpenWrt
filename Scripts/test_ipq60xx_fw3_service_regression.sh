#!/bin/bash

# 说明：回归验证 IPQ60XX-NOWIFI 的 FW3 导出配置保留关键服务插件与语言包。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

OUTPUT="$TMPDIR/ipq60xx-fw3.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "IPQ60XX-NOWIFI" \
	--fw "fw3" \
	--output "$OUTPUT" >/dev/null

grep -n '^CONFIG_PACKAGE_luci-app-accesscontrol=' "$OUTPUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-accesscontrol=y'
grep -n '^CONFIG_PACKAGE_luci-i18n-accesscontrol-zh-cn=' "$OUTPUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-accesscontrol-zh-cn=y'
grep -n '^CONFIG_PACKAGE_luci-app-adguardhome=' "$OUTPUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-adguardhome=y'
grep -n '^CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=' "$OUTPUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=y'
grep -n '^CONFIG_PACKAGE_luci-app-socat=' "$OUTPUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-socat=y'
grep -n '^CONFIG_PACKAGE_luci-app-vlmcsd=' "$OUTPUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-vlmcsd=y'

echo "test_ipq60xx_fw3_service_regression: ok"
