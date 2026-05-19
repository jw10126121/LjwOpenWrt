#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW3_OUT="$TMPDIR/jd-ax6600-fw3.txt"
FW4_OUT="$TMPDIR/jd-ax6600-fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "JD-AX6600-WIFI" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "JD-AX6600-WIFI" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=n'
grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=y'
grep -n '^CONFIG_PACKAGE_ath11k-firmware-ipq6018=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ath11k-firmware-ipq6018=y'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=y'

grep -n '^CONFIG_PACKAGE_firewall4=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall4=y'
grep -n '^CONFIG_PACKAGE_firewall=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_firewall=n'
grep -n '^CONFIG_PACKAGE_luci-app-homeproxy=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-homeproxy=y'
grep -n '^CONFIG_PACKAGE_luci-app-ssr-plus=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-ssr-plus=n'

if grep -n '^CONFIG_PACKAGE_ipq-wifi-jdcloud_re-cs-02=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ipq-wifi-jdcloud_re-cs-02=y'; then
	:
else
	echo "JD-AX6600-WIFI should enable the jdcloud_re-cs-02 board data package" >&2
	exit 1
fi

echo "test_jd_ax6600_wifi_export: ok"
