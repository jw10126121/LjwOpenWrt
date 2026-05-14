#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

BASE_OUT="$TMPDIR/ipq60xx-base.txt"
AX1800_OUT="$TMPDIR/ipq60xx-ax1800pro-wifi.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "IPQ60XX-NOWIFI" \
	--fw "fw3" \
	--output "$BASE_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "IPQ60XX-NOWIFI" \
	--fw "fw3" \
	--overlay "ax1800pro-wifi" \
	--output "$AX1800_OUT" >/dev/null

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=n'
grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=n'
grep -n '^CONFIG_PACKAGE_ath11k-firmware-ipq6018=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ath11k-firmware-ipq6018=n'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=n'

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=n'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y'
grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=y'
grep -n '^CONFIG_PACKAGE_kmod-ath11k-ahb=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k-ahb=y'
grep -n '^CONFIG_PACKAGE_kmod-ath11k-pci=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k-pci=n'
grep -n '^CONFIG_PACKAGE_ath11k-firmware-ipq6018=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ath11k-firmware-ipq6018=y'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=y'
grep -n '^CONFIG_PACKAGE_hostapd-common=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd-common=y'

if grep -q '^CONFIG_PACKAGE_ipq-wifi-jdcloud_re-ss-01=y$' "$AX1800_OUT"; then
	:
elif grep -q '^CONFIG_PACKAGE_ipq-wifi-jdcloud_ax1800pro=y$' "$AX1800_OUT"; then
	:
else
	echo "AX1800PRO-WIFI overlay should enable a JDCloud AX1800 Pro board data package" >&2
	exit 1
fi

echo "test_ipq60xx_ax1800pro_wifi_overlay: ok"
