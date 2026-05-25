#!/bin/bash

# 说明：验证 Organize_Packages.sh 只会按手工 PACKAGE_OVERRIDES 整理目标目录。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Organize_Packages.sh"

TMPDIR=$(mktemp -d)
CONFIG_FILE="$TMPDIR/.config"
GENERATED_OVERRIDES="$TMPDIR/generated_overrides.txt"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

touch "$TMPDIR/luci-app-ssr-plus_190_all.ipk"
touch "$TMPDIR/luci-i18n-ssr-plus-zh-cn_git-1_all.ipk"
touch "$TMPDIR/dnsmasq-full_1_aarch64.ipk"
touch "$TMPDIR/jq_1_aarch64.ipk"
touch "$TMPDIR/ip-full_1_aarch64.ipk"
touch "$TMPDIR/curl_1_aarch64.ipk"
touch "$TMPDIR/libustream-openssl20201210_1_aarch64.ipk"
touch "$TMPDIR/libpcap1_1_aarch64.ipk"
touch "$TMPDIR/libudns_1_aarch64.ipk"
touch "$TMPDIR/libuci-lua_1_aarch64.ipk"
touch "$TMPDIR/nping_1_aarch64.ipk"
touch "$TMPDIR/resolveip_1_aarch64.ipk"
touch "$TMPDIR/lua-neturl_1_all.ipk"
touch "$TMPDIR/libev_1_aarch64.ipk"
touch "$TMPDIR/libpcre2_1_aarch64.ipk"
touch "$TMPDIR/libsodium_1_aarch64.ipk"
touch "$TMPDIR/dns2socks_1_aarch64.ipk"
touch "$TMPDIR/dns2tcp_1_aarch64.ipk"
touch "$TMPDIR/ipt2socks_1_aarch64.ipk"
touch "$TMPDIR/chinadns-ng_1_aarch64.ipk"
touch "$TMPDIR/mosdns_1_aarch64.ipk"
touch "$TMPDIR/microsocks_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-libev-ss-local_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-libev-ss-redir_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-libev-ss-server_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-rust-sslocal_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-rust-ssserver_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-check_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-local_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-redir_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-server_1_aarch64.ipk"
touch "$TMPDIR/simple-obfs-client_1_aarch64.ipk"
touch "$TMPDIR/tcping_1_aarch64.ipk"
touch "$TMPDIR/xray-core_1_aarch64.ipk"
touch "$TMPDIR/coreutils_1_aarch64.ipk"
touch "$TMPDIR/coreutils-base64_1_aarch64.ipk"
touch "$TMPDIR/ca-bundle_1_all.ipk"
touch "$TMPDIR/libopenssl3_1_aarch64.ipk"
touch "$TMPDIR/libubox20240329_1_aarch64.ipk"
touch "$TMPDIR/lyaml_1_aarch64.ipk"
touch "$TMPDIR/xz-utils_1_aarch64.ipk"
touch "$TMPDIR/luci-app-openclash_1_all.ipk"
touch "$TMPDIR/luci-app-3cat_1_all.ipk"
touch "$TMPDIR/luci-i18n-3cat-zh-cn_1_all.ipk"
touch "$TMPDIR/3proxy_1_aarch64.ipk"
touch "$TMPDIR/3proxy-mod-tcppm_1_aarch64.ipk"
touch "$TMPDIR/3proxy-mod-udppm_1_aarch64.ipk"
touch "$TMPDIR/luci-app-socat_1_all.ipk"
touch "$TMPDIR/luci-i18n-socat-zh-cn_1_all.ipk"
touch "$TMPDIR/socat_1_aarch64.ipk"
touch "$TMPDIR/kmod-inet-diag_1_aarch64.ipk"
touch "$TMPDIR/coreutils-nohup_1_aarch64.ipk"
touch "$TMPDIR/libcap-bin_1_aarch64.ipk"
touch "$TMPDIR/libgmp10_1_aarch64.ipk"
touch "$TMPDIR/libruby_1_aarch64.ipk"
touch "$TMPDIR/libyaml_1_aarch64.ipk"
touch "$TMPDIR/ruby_1_aarch64.ipk"
touch "$TMPDIR/ruby-bigdecimal_1_aarch64.ipk"
touch "$TMPDIR/ruby-date_1_aarch64.ipk"
touch "$TMPDIR/ruby-digest_1_aarch64.ipk"
touch "$TMPDIR/ruby-enc_1_aarch64.ipk"
touch "$TMPDIR/ruby-forwardable_1_aarch64.ipk"
touch "$TMPDIR/ruby-pstore_1_aarch64.ipk"
touch "$TMPDIR/ruby-psych_1_aarch64.ipk"
touch "$TMPDIR/ruby-stringio_1_aarch64.ipk"
touch "$TMPDIR/ruby-strscan_1_aarch64.ipk"
touch "$TMPDIR/ruby-yaml_1_aarch64.ipk"
touch "$TMPDIR/unzip_1_aarch64.ipk"
touch "$TMPDIR/kmod-nft-tproxy_1_aarch64.ipk"
touch "$TMPDIR/luci-app-openvpn_1_all.ipk"
touch "$TMPDIR/luci-i18n-openvpn-zh-cn_1_all.ipk"
touch "$TMPDIR/luci-app-basic_1_all.ipk"
touch "$TMPDIR/luci-i18n-basic-zh-cn_1_all.ipk"
touch "$TMPDIR/luci-app-frps_1_all.ipk"
touch "$TMPDIR/luci-i18n-frps-zh-cn_1_all.ipk"
touch "$TMPDIR/frps_1_aarch64.ipk"
touch "$TMPDIR/luci-app-adguardhome_1_all.ipk"
touch "$TMPDIR/luci-i18n-adguardhome-zh-cn_1_all.ipk"
touch "$TMPDIR/adguardhome_1_aarch64.ipk"
touch "$TMPDIR/ca-certs_1_all.ipk"
touch "$TMPDIR/wget-ssl_1_aarch64.ipk"
touch "$TMPDIR/libcurl_1_aarch64.ipk"
touch "$TMPDIR/libgnutls_1_aarch64.ipk"
touch "$TMPDIR/libmbedtls_1_aarch64.ipk"
touch "$TMPDIR/libopenssl_1_aarch64.ipk"
touch "$TMPDIR/libwolfssl_1_aarch64.ipk"
touch "$TMPDIR/kmod-crypto-hw-padlock_1_aarch64.ipk"
touch "$TMPDIR/kmod-crypto-user_1_aarch64.ipk"
touch "$TMPDIR/kmod-cryptodev_1_aarch64.ipk"
touch "$TMPDIR/libatomic_1_aarch64.ipk"
touch "$TMPDIR/libgcc_1_aarch64.ipk"
touch "$TMPDIR/luci-app-easytier_1_all.ipk"
touch "$TMPDIR/luci-i18n-easytier-zh-cn_1_all.ipk"
touch "$TMPDIR/easytier_2.6.4_aarch64.ipk"
touch "$TMPDIR/easytier-noweb_2.6.4_aarch64.ipk"
touch "$TMPDIR/kmod-tun_1_aarch64.ipk"
touch "$TMPDIR/luci-app-mosdns_1_all.ipk"
touch "$TMPDIR/luci-i18n-mosdns-zh-cn_1_all.ipk"
touch "$TMPDIR/v2dat_1_aarch64.ipk"
touch "$TMPDIR/v2ray-geoip_1_all.ipk"
touch "$TMPDIR/v2ray-geosite_1_all.ipk"
touch "$TMPDIR/luci-app-nlbwmon_1_all.ipk"
touch "$TMPDIR/luci-i18n-nlbwmon-zh-cn_1_all.ipk"
touch "$TMPDIR/nlbwmon_1_aarch64.ipk"
touch "$TMPDIR/luci-app-arpbind_1_all.ipk"
touch "$TMPDIR/luci-i18n-arpbind-zh-cn_1_all.ipk"
touch "$TMPDIR/luci-app-onliner_1_all.ipk"
touch "$TMPDIR/luci-i18n-onliner-zh-cn_1_all.ipk"
touch "$TMPDIR/arp-scan_1_aarch64.ipk"
touch "$TMPDIR/libpcap_1_aarch64.ipk"
touch "$TMPDIR/luci-app-turboacc_1_all.ipk"
touch "$TMPDIR/luci-i18n-turboacc-zh-cn_1_all.ipk"
touch "$TMPDIR/kmod-fast-classifier_1_aarch64.ipk"
touch "$TMPDIR/kmod-ipt-offload_1_aarch64.ipk"
touch "$TMPDIR/kmod-shortcut-fe-cm_1_aarch64.ipk"
touch "$TMPDIR/kmod-tcp-bbr_1_aarch64.ipk"
touch "$TMPDIR/luci-app-vsftpd_1_all.ipk"
touch "$TMPDIR/luci-i18n-vsftpd-zh-cn_1_all.ipk"
touch "$TMPDIR/vsftpd-alt_1_aarch64.ipk"
touch "$TMPDIR/kmod-usb-core_6.6.1-r1_aarch64.ipk"
touch "$TMPDIR/kmod-usb2_6.6.1-r1_aarch64.apk"
touch "$TMPDIR/usbutils_017-r1_aarch64.ipk"
touch "$TMPDIR/kmod-usb2aaaa_1_aarch64.ipk"

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-ssr-plus=m
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-3cat=y
CONFIG_PACKAGE_luci-app-socat=m
CONFIG_PACKAGE_luci-app-easytier=y
CONFIG_PACKAGE_luci-app-openvpn=m
CONFIG_PACKAGE_luci-app-adguardhome=m
CONFIG_PACKAGE_luci-app-mosdns=m
CONFIG_PACKAGE_luci-app-onliner=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-basic=m
CONFIG_PACKAGE_luci-app-rclone_INCLUDE_rclone-webui=y
EOF

cat > "$GENERATED_OVERRIDES" <<'EOF'
luci-app-openvpn|luci-app-openvpn_ luci-i18n-openvpn-zh-cn_
luci-app-basic|luci-app-basic_ luci-i18n-basic-zh-cn_
EOF

# 只允许手工内置规则生效；自动分组与外部生成规则都不应再创建目录。
bash "$TARGET_SCRIPT" "$TMPDIR" "$CONFIG_FILE" "$GENERATED_OVERRIDES" >/dev/null

SSRPLUS_DIR="$TMPDIR/luci-app-ssr-plus"
required_files="
luci-app-ssr-plus_190_all.ipk
luci-i18n-ssr-plus-zh-cn_git-1_all.ipk
dnsmasq-full_1_aarch64.ipk
jq_1_aarch64.ipk
ip-full_1_aarch64.ipk
curl_1_aarch64.ipk
ipt2socks_1_aarch64.ipk
chinadns-ng_1_aarch64.ipk
libustream-openssl20201210_1_aarch64.ipk
shadowsocks-libev-ss-local_1_aarch64.ipk
shadowsocks-libev-ss-redir_1_aarch64.ipk
shadowsocks-libev-ss-server_1_aarch64.ipk
shadowsocksr-libev-ssr-local_1_aarch64.ipk
shadowsocksr-libev-ssr-redir_1_aarch64.ipk
shadowsocksr-libev-ssr-server_1_aarch64.ipk
coreutils_1_aarch64.ipk
coreutils-base64_1_aarch64.ipk
ca-bundle_1_all.ipk
libopenssl3_1_aarch64.ipk
libubox20240329_1_aarch64.ipk
lyaml_1_aarch64.ipk
xz-utils_1_aarch64.ipk
"

for filename in $required_files; do
	if [ ! -f "$SSRPLUS_DIR/$filename" ]; then
		echo "Missing expected file: $filename" >&2
		exit 1
	fi
done

THREECAT_DIR="$TMPDIR/luci-app-3cat"
threecat_required_files="
luci-app-3cat_1_all.ipk
luci-i18n-3cat-zh-cn_1_all.ipk
3proxy_1_aarch64.ipk
3proxy-mod-tcppm_1_aarch64.ipk
3proxy-mod-udppm_1_aarch64.ipk
"

for filename in $threecat_required_files; do
	if [ ! -f "$THREECAT_DIR/$filename" ]; then
		echo "Missing expected 3cat file: $filename" >&2
		exit 1
	fi
done

SOCAT_DIR="$TMPDIR/luci-app-socat"
socat_required_files="
luci-app-socat_1_all.ipk
luci-i18n-socat-zh-cn_1_all.ipk
socat_1_aarch64.ipk
"

for filename in $socat_required_files; do
	if [ ! -f "$SOCAT_DIR/$filename" ]; then
		echo "Missing expected socat file: $filename" >&2
		exit 1
	fi
done

EASYTIER_DIR="$TMPDIR/luci-app-easytier"
easytier_required_files="
luci-app-easytier_1_all.ipk
luci-i18n-easytier-zh-cn_1_all.ipk
easytier_2.6.4_aarch64.ipk
easytier-noweb_2.6.4_aarch64.ipk
kmod-tun_1_aarch64.ipk
"

for filename in $easytier_required_files; do
	if [ ! -f "$EASYTIER_DIR/$filename" ]; then
		echo "Missing expected EasyTier file: $filename" >&2
		exit 1
	fi
done

ADGUARDHOME_DIR="$TMPDIR/luci-app-adguardhome"
adguardhome_required_files="
luci-app-adguardhome_1_all.ipk
luci-i18n-adguardhome-zh-cn_1_all.ipk
adguardhome_1_aarch64.ipk
ca-certs_1_all.ipk
curl_1_aarch64.ipk
wget-ssl_1_aarch64.ipk
"

for filename in $adguardhome_required_files; do
	if [ ! -f "$ADGUARDHOME_DIR/$filename" ]; then
		echo "Missing expected AdGuardHome file: $filename" >&2
		exit 1
	fi
done

MOSDNS_DIR="$TMPDIR/luci-app-mosdns"
mosdns_required_files="
luci-app-mosdns_1_all.ipk
luci-i18n-mosdns-zh-cn_1_all.ipk
mosdns_1_aarch64.ipk
v2dat_1_aarch64.ipk
v2ray-geoip_1_all.ipk
v2ray-geosite_1_all.ipk
"

for filename in $mosdns_required_files; do
	if [ ! -f "$MOSDNS_DIR/$filename" ]; then
		echo "Missing expected MosDNS file: $filename" >&2
		exit 1
	fi
done

ONLINER_DIR="$TMPDIR/luci-app-onliner"
onliner_required_files="
luci-app-onliner_1_all.ipk
luci-i18n-onliner-zh-cn_1_all.ipk
arp-scan_1_aarch64.ipk
"

for filename in $onliner_required_files; do
	if [ ! -f "$ONLINER_DIR/$filename" ]; then
		echo "Missing expected Onliner file: $filename" >&2
		exit 1
	fi
done

TURBOACC_DIR="$TMPDIR/luci-app-turboacc"
turboacc_required_files="
luci-app-turboacc_1_all.ipk
luci-i18n-turboacc-zh-cn_1_all.ipk
kmod-fast-classifier_1_aarch64.ipk
kmod-ipt-offload_1_aarch64.ipk
kmod-shortcut-fe-cm_1_aarch64.ipk
kmod-tcp-bbr_1_aarch64.ipk
"

for filename in $turboacc_required_files; do
	if [ ! -f "$TURBOACC_DIR/$filename" ]; then
		echo "Missing expected TurboACC file: $filename" >&2
		exit 1
	fi
done

OPENCLASH_DIR="$TMPDIR/luci-app-openclash"
openclash_required_files="
luci-app-openclash_1_all.ipk
kmod-inet-diag_1_aarch64.ipk
coreutils-nohup_1_aarch64.ipk
libcap-bin_1_aarch64.ipk
libgmp10_1_aarch64.ipk
libruby_1_aarch64.ipk
libyaml_1_aarch64.ipk
ruby_1_aarch64.ipk
ruby-bigdecimal_1_aarch64.ipk
ruby-date_1_aarch64.ipk
ruby-digest_1_aarch64.ipk
ruby-enc_1_aarch64.ipk
ruby-forwardable_1_aarch64.ipk
ruby-pstore_1_aarch64.ipk
ruby-psych_1_aarch64.ipk
ruby-stringio_1_aarch64.ipk
ruby-strscan_1_aarch64.ipk
ruby-yaml_1_aarch64.ipk
unzip_1_aarch64.ipk
kmod-nft-tproxy_1_aarch64.ipk
"

for filename in $openclash_required_files; do
	if [ ! -f "$OPENCLASH_DIR/$filename" ]; then
		echo "Missing expected OpenClash file: $filename" >&2
		exit 1
	fi
done

[ ! -d "$TMPDIR/luci-app-openvpn" ] || {
	echo "Unexpected auto-grouped directory created: luci-app-openvpn" >&2
	exit 1
}
[ ! -d "$TMPDIR/luci-app-basic" ] || {
	echo "Unexpected auto-grouped directory created: luci-app-basic" >&2
	exit 1
}

[ ! -d "$TMPDIR/luci-app-rclone_INCLUDE_rclone-webui" ] || {
	echo "Unexpected include-feature directory created" >&2
	exit 1
}

stale_disabled_files="
luci-app-frps_1_all.ipk
luci-i18n-frps-zh-cn_1_all.ipk
frps_1_aarch64.ipk
luci-app-nlbwmon_1_all.ipk
luci-i18n-nlbwmon-zh-cn_1_all.ipk
nlbwmon_1_aarch64.ipk
luci-app-arpbind_1_all.ipk
luci-i18n-arpbind-zh-cn_1_all.ipk
luci-app-vsftpd_1_all.ipk
luci-i18n-vsftpd-zh-cn_1_all.ipk
vsftpd-alt_1_aarch64.ipk
"

for filename in $stale_disabled_files; do
	if [ -e "$TMPDIR/$filename" ]; then
		echo "Stale disabled package should have been removed: $filename" >&2
		exit 1
	fi
done

[ ! -d "$TMPDIR/luci-app-frps" ] || {
	echo "Unexpected disabled directory created: luci-app-frps" >&2
	exit 1
}
[ ! -d "$TMPDIR/luci-app-nlbwmon" ] || {
	echo "Unexpected disabled directory created: luci-app-nlbwmon" >&2
	exit 1
}
[ ! -d "$TMPDIR/luci-app-arpbind" ] || {
	echo "Unexpected disabled directory created: luci-app-arpbind" >&2
	exit 1
}
[ ! -d "$TMPDIR/luci-app-vsftpd" ] || {
	echo "Unexpected disabled directory created: luci-app-vsftpd" >&2
	exit 1
}

USB_DIR="$TMPDIR/usb"
usb_required_files="
kmod-usb-core_6.6.1-r1_aarch64.ipk
kmod-usb2_6.6.1-r1_aarch64.apk
usbutils_017-r1_aarch64.ipk
"

for filename in $usb_required_files; do
	if [ ! -f "$USB_DIR/$filename" ]; then
		echo "Missing expected USB file: $filename" >&2
		exit 1
	fi
done

for filename in $usb_required_files; do
	if [ -e "$TMPDIR/$filename" ]; then
		echo "USB package should have been moved into usb directory: $filename" >&2
		exit 1
	fi
done

[ ! -e "$USB_DIR/kmod-usb2aaaa_1_aarch64.ipk" ] || {
	echo "Unexpected loosely matched USB file moved into usb directory" >&2
	exit 1
}

[ -f "$TMPDIR/kmod-usb2aaaa_1_aarch64.ipk" ] || {
	echo "Non-USB-prefixed lookalike package should stay in root directory" >&2
	exit 1
}

echo "test_organize_packages: ok"
