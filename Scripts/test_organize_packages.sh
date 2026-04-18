#!/bin/bash

# 说明：验证 Organize_Packages.sh 是否能按手工规则和自动规则把包整理到目标目录。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Organize_Packages.sh"

TMPDIR=$(mktemp -d)
CONFIG_FILE="$TMPDIR/.config"
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
touch "$TMPDIR/luci-app-openvpn_1_all.ipk"
touch "$TMPDIR/luci-i18n-openvpn-zh-cn_1_all.ipk"
touch "$TMPDIR/luci-theme-argon_1_all.ipk"
touch "$TMPDIR/luci-i18n-argon-zh-cn_1_all.ipk"

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-ssr-plus=m
CONFIG_PACKAGE_luci-app-openvpn=m
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-rclone_INCLUDE_rclone-webui=y
EOF

# 同时覆盖：手工内置规则、自动主题分组，以及“包含功能开关不应误生成目录”的场景。
bash "$TARGET_SCRIPT" "$TMPDIR" "$CONFIG_FILE" >/dev/null

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

OPENVPN_DIR="$TMPDIR/luci-app-openvpn"
ARGON_DIR="$TMPDIR/luci-theme-argon"

[ -f "$OPENVPN_DIR/luci-app-openvpn_1_all.ipk" ] || {
	echo "Missing auto-grouped file: luci-app-openvpn_1_all.ipk" >&2
	exit 1
}
[ -f "$OPENVPN_DIR/luci-i18n-openvpn-zh-cn_1_all.ipk" ] || {
	echo "Missing auto-grouped file: luci-i18n-openvpn-zh-cn_1_all.ipk" >&2
	exit 1
}
[ -f "$ARGON_DIR/luci-theme-argon_1_all.ipk" ] || {
	echo "Missing auto-grouped file: luci-theme-argon_1_all.ipk" >&2
	exit 1
}
[ -f "$ARGON_DIR/luci-i18n-argon-zh-cn_1_all.ipk" ] || {
	echo "Missing auto-grouped file: luci-i18n-argon-zh-cn_1_all.ipk" >&2
	exit 1
}

[ ! -d "$TMPDIR/luci-app-rclone_INCLUDE_rclone-webui" ] || {
	echo "Unexpected include-feature directory created" >&2
	exit 1
}

echo "test_organize_packages: ok"
