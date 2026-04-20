#!/bin/bash

# 说明：MT6000-WIFI 的 FW4 叠加层只应保留真正需要的 FW4 扩展包，
# 不应继续把 mwan3 / mwan3helper 带入该组合。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW4_OUT="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "MT6000-WIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

grep -n '^CONFIG_PACKAGE_luci-app-openvpn=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openvpn=y'
grep -n '^CONFIG_PACKAGE_luci-app-openvpn-server=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openvpn-server=y'
grep -n '^CONFIG_PACKAGE_luci-app-dockerman=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-dockerman=y'
grep -n '^CONFIG_PACKAGE_luci-app-mosdns=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-mosdns=y'

if grep -q '^CONFIG_PACKAGE_luci-app-mwan3=' "$FW4_OUT"; then
	echo "MT6000-WIFI FW4 should not include luci-app-mwan3" >&2
	exit 1
fi

if grep -q '^CONFIG_PACKAGE_luci-app-mwan3helper=' "$FW4_OUT"; then
	echo "MT6000-WIFI FW4 should not include luci-app-mwan3helper" >&2
	exit 1
fi

echo "test_mt6000_fw4_overlay_packages: ok"
