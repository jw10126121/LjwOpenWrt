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
touch "$TMPDIR/luci-app-openvpn_1_all.ipk"
touch "$TMPDIR/luci-i18n-openvpn-zh-cn_1_all.ipk"
touch "$TMPDIR/luci-app-basic_1_all.ipk"
touch "$TMPDIR/luci-i18n-basic-zh-cn_1_all.ipk"

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-ssr-plus=m
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

echo "test_organize_packages: ok"
