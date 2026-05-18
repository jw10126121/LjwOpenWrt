#!/bin/bash

# 说明：验证 CMIOT-AX18-NOWIFI 在 FW4 导出下只保留兼容 FW4 的关键防火墙/代理组合。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW4_OUT="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "CMIOT-AX18-NOWIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

grep -n '^CONFIG_PACKAGE_firewall4=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall4=y'
grep -n '^CONFIG_PACKAGE_firewall=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall=n'
grep -n '^CONFIG_PACKAGE_iptables=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iptables=n'
grep -n '^CONFIG_PACKAGE_nftables=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_nftables=y'
grep -n '^CONFIG_PACKAGE_luci-app-openclash=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openclash=m'
grep -n '^CONFIG_PACKAGE_luci-app-homeproxy=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-homeproxy=y'
grep -n '^CONFIG_PACKAGE_luci-app-turboacc=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-turboacc=n'
grep -n '^CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=n'
grep -n '^CONFIG_PACKAGE_luci-app-adguardhome=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-adguardhome=n'
grep -n '^CONFIG_PACKAGE_luci-app-ssr-plus=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-ssr-plus=n'
grep -n '^CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn=n'

echo "test_cmiot_ax18_fw4_packages: ok"
