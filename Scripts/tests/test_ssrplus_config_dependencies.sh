#!/bin/bash

# 说明：凡是显式启用 SSR Plus 的配置，必须同步显式启用 chinadns-ng 与 ipt2socks。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

CONFIG_FILES="
$REPO_ROOT/Config/CMIOT-AX18-NOWIFI.txt
$REPO_ROOT/Config/JD-AX1800PRO-WIFI.txt
$REPO_ROOT/Config/JD-AX6600-WIFI.txt
$REPO_ROOT/Config/GL-MT6000-WIFI.txt
$REPO_ROOT/Config/x86.txt
"

for file in $CONFIG_FILES; do
	ssrplus_state=$(sed -n 's/^CONFIG_PACKAGE_luci-app-ssr-plus=\([ymn]\).*$/\1/p' "$file" | tail -n 1)
	[ -n "$ssrplus_state" ] || continue

	chinadns_state=$(sed -n 's/^CONFIG_PACKAGE_chinadns-ng=\([ymn]\).*$/\1/p' "$file" | tail -n 1)
	ipt2socks_state=$(sed -n 's/^CONFIG_PACKAGE_ipt2socks=\([ymn]\).*$/\1/p' "$file" | tail -n 1)

	if [ "$ssrplus_state" = "y" ] || [ "$ssrplus_state" = "m" ]; then
		if [ "$chinadns_state" != "$ssrplus_state" ]; then
			echo "SSR Plus config missing matching chinadns-ng state in $file: expected $ssrplus_state, got ${chinadns_state:-<unset>}" >&2
			exit 1
		fi
		if [ "$ipt2socks_state" != "$ssrplus_state" ]; then
			echo "SSR Plus config missing matching ipt2socks state in $file: expected $ssrplus_state, got ${ipt2socks_state:-<unset>}" >&2
			exit 1
		fi
	fi
done

echo "test_ssrplus_config_dependencies: ok"
