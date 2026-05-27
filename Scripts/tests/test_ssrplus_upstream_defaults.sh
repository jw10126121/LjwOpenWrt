#!/bin/bash

# 说明：SSR Plus 的细分开关不再在仓库参数化配置里显式写值，统一交给上游默认处理。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

CONFIG_FILES="
$REPO_ROOT/Config/MT6000-WIFI-FW3.txt
$REPO_ROOT/Config/CMIOT-AX18-NOWIFI-FW3.txt
$REPO_ROOT/Config/MIR3G-WIFI-MINI-FW3.txt
$REPO_ROOT/Config/MT6000-WIFI-MINI-FW3.txt
$REPO_ROOT/Config/CMIOT-AX18-NOWIFI-MINI-FW3.txt
"

PATTERNS="
luci-app-ssr-plus_Iptables_Transparent_Proxy
luci-app-ssr-plus_INCLUDE_libustream-openssl
luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust_Client
luci-app-ssr-plus_INCLUDE_Shadowsocks_Rust_Server
luci-app-ssr-plus_INCLUDE_Shadowsocks_NONE_Server
luci-app-ssr-plus_INCLUDE_Xray
luci-app-ssr-plus_INCLUDE_MosDNS
luci-app-ssr-plus_INCLUDE_Mihomo
luci-app-ssr-plus_INCLUDE_Shadowsocks_Simple_Obfs
luci-app-ssr-plus_INCLUDE_ShadowsocksR_Libev_Client
"

for file in $CONFIG_FILES; do
	for pattern in $PATTERNS; do
		if rg -n "$pattern" "$file" >/dev/null 2>&1; then
			echo "SSR Plus upstream-default option should not be pinned in $file: $pattern" >&2
			exit 1
		fi
	done
done

if rg -n 'luci-app-ssr-plus_(Iptables_Transparent_Proxy|INCLUDE_libustream-openssl|INCLUDE_Shadowsocks_Rust_Client|INCLUDE_Shadowsocks_Rust_Server|INCLUDE_Shadowsocks_NONE_Server|INCLUDE_Xray|INCLUDE_MosDNS|INCLUDE_Mihomo|INCLUDE_Shadowsocks_Simple_Obfs|INCLUDE_ShadowsocksR_Libev_Client)' "$REPO_ROOT/Scripts/readme.txt" >/dev/null 2>&1; then
	echo "SSR Plus upstream-default options should not be listed in Scripts/readme.txt" >&2
	exit 1
fi

echo "test_ssrplus_upstream_defaults: ok"
