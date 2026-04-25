#!/bin/bash

# 说明：验证 Organize_Packages.sh 只会按手工 PACKAGE_OVERRIDES 整理目标目录。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
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
touch "$TMPDIR/mosdns_1_aarch64.ipk"
touch "$TMPDIR/microsocks_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-rust-sslocal_1_aarch64.ipk"
touch "$TMPDIR/shadowsocks-rust-ssserver_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-check_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-local_1_aarch64.ipk"
touch "$TMPDIR/shadowsocksr-libev-ssr-redir_1_aarch64.ipk"
touch "$TMPDIR/simple-obfs-client_1_aarch64.ipk"
touch "$TMPDIR/tcping_1_aarch64.ipk"
touch "$TMPDIR/xray-core_1_aarch64.ipk"
touch "$TMPDIR/coreutils_1_aarch64.ipk"
touch "$TMPDIR/coreutils-base64_1_aarch64.ipk"
touch "$TMPDIR/ca-bundle_1_all.ipk"
touch "$TMPDIR/libopenssl3_1_aarch64.ipk"
touch "$TMPDIR/libubox20240329_1_aarch64.ipk"
touch "$TMPDIR/luci-app-openclash_1_all.ipk"
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
touch "$TMPDIR/luci-app-nlbwmon_1_all.ipk"
touch "$TMPDIR/luci-i18n-nlbwmon-zh-cn_1_all.ipk"
touch "$TMPDIR/nlbwmon_1_aarch64.ipk"
touch "$TMPDIR/luci-app-arpbind_1_all.ipk"
touch "$TMPDIR/luci-i18n-arpbind-zh-cn_1_all.ipk"
touch "$TMPDIR/luci-app-vsftpd_1_all.ipk"
touch "$TMPDIR/luci-i18n-vsftpd-zh-cn_1_all.ipk"
touch "$TMPDIR/vsftpd-alt_1_aarch64.ipk"

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-ssr-plus=m
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-openvpn=m
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
libustream-openssl20201210_1_aarch64.ipk
coreutils_1_aarch64.ipk
coreutils-base64_1_aarch64.ipk
ca-bundle_1_all.ipk
libopenssl3_1_aarch64.ipk
libubox20240329_1_aarch64.ipk
"

for filename in $required_files; do
	if [ ! -f "$SSRPLUS_DIR/$filename" ]; then
		echo "Missing expected file: $filename" >&2
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

echo "test_organize_packages: ok"
