#!/bin/bash

# 说明：验证只允许在特定防火墙栈下启用的包，最终合并结果符合预期。

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
	--device "IPQ60XX-NOWIFI" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "IPQ60XX-NOWIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

grep -n '^CONFIG_PACKAGE_luci-app-turboacc=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-turboacc=y'
grep -n '^CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=y'
grep -n '^CONFIG_PACKAGE_luci-app-turboacc=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-turboacc=n'
grep -n '^CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=n'

echo "test_fw_scoped_packages: ok"
