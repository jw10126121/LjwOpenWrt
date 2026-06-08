#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

assert_fw4_core() {
	local device="$1"
	local out_file="$TMPDIR/${device}.txt"

	bash "$EXPORT_SCRIPT" \
		--config-dir "$SCRIPT_DIR/../Config" \
		--device "$device" \
		--fw "fw4" \
		--output "$out_file" >/dev/null

	grep -n '^CONFIG_PACKAGE_firewall4=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall4=y'
	grep -n '^CONFIG_PACKAGE_firewall=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall=n'
	grep -n '^CONFIG_PACKAGE_iptables=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iptables=n'
	grep -n '^CONFIG_PACKAGE_nftables=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_nftables=y'
	grep -n '^CONFIG_PACKAGE_luci-app-homeproxy=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-homeproxy=y'
	grep -n '^CONFIG_PACKAGE_luci-app-turboacc=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-turboacc=n'
	grep -n '^CONFIG_PACKAGE_luci-app-ssr-plus=' "$out_file" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-ssr-plus=n'
}

for device in \
	CMIOT-AX18-NOWIFI \
	JD-AX1800PRO-WIFI
do
	assert_fw4_core "$device"
done

echo "test_split_device_fw4_exports: ok"
