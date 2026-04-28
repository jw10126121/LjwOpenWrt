#!/bin/bash

# 说明：MT6000-WIFI 的一组设备共用包
# 已统一收口到 Config/MT6000-WIFI-FW3.txt，不再拆成普通设备层 + device-overlays。

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
	grep -n '^CONFIG_PACKAGE_luci-app-dockerman=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-dockerman=m'
	grep -n '^CONFIG_PACKAGE_luci-app-mosdns=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-mosdns=m'
	grep -n '^CONFIG_PACKAGE_luci-app-bandix=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-bandix=m'
	grep -n '^CONFIG_PACKAGE_bandix=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_bandix=m'
	grep -n '^CONFIG_PACKAGE_luci-app-nlbwmon=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-nlbwmon=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-nlbwmon-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-nlbwmon-zh-cn=m'
	grep -n '^CONFIG_PACKAGE_luci-app-openvpn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openvpn=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-openvpn-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-openvpn-zh-cn=m'
	grep -n '^CONFIG_PACKAGE_luci-app-openvpn-server=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openvpn-server=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-openvpn-server-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-openvpn-server-zh-cn=m'
	grep -n '^CONFIG_PACKAGE_luci-app-samba4=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-samba4=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-samba4-zh-cn=m'
	grep -n '^CONFIG_PACKAGE_luci-app-hd-idle=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-hd-idle=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-hd-idle-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-hd-idle-zh-cn=m'
	grep -n '^CONFIG_PACKAGE_hd-idle=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hd-idle=m'
	grep -n '^CONFIG_PACKAGE_luci-app-usb-printer=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-usb-printer=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-usb-printer-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-usb-printer-zh-cn=m'
	grep -n '^CONFIG_PACKAGE_luci-app-vsftpd=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-vsftpd=m'
	grep -n '^CONFIG_PACKAGE_luci-i18n-vsftpd-zh-cn=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-vsftpd-zh-cn=m'
done

grep -n '^CONFIG_PACKAGE_luci-app-verysync=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-verysync=m'
grep -n '^CONFIG_PACKAGE_luci-i18n-verysync-zh-cn=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-verysync-zh-cn=m'
grep -n '^CONFIG_PACKAGE_luci-app-verysync=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-verysync=m'
grep -n '^CONFIG_PACKAGE_luci-i18n-verysync-zh-cn=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-verysync-zh-cn=m'
grep -n '^CONFIG_PACKAGE_verysync=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_verysync=m'

echo "test_mt6000_shared_packages: ok"
