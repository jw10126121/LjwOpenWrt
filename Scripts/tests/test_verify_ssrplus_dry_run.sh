#!/bin/bash

# 说明：为 verify_ssrplus_dry_run.sh 生成一组带依赖关系的测试包，验证其输出摘要。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/verify_ssrplus_dry_run.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

make_ipk() {
	# 生成只带 control 元数据的空包，足够支撑依赖解析逻辑测试。
	local output_path=$1
	local package_name=$2
	local depends=${3-}
	local provides=${4-}
	local workdir
	workdir=$(mktemp -d "$TMPDIR/pkg.XXXXXX")

	mkdir -p "$workdir/control"
	{
		echo "Package: $package_name"
		echo "Version: 1"
		echo "Architecture: all"
		[ -n "$depends" ] && echo "Depends: $depends"
		[ -n "$provides" ] && echo "Provides: $provides"
	} > "$workdir/control/control"

	tar -czf "$workdir/control.tar.gz" -C "$workdir/control" .
	mkdir -p "$workdir/data"
	tar -czf "$workdir/data.tar.gz" -C "$workdir/data" .
	printf '2.0\n' > "$workdir/debian-binary"
	tar -czf "$output_path" -C "$workdir" debian-binary control.tar.gz data.tar.gz
	rm -rf "$workdir"
}

mkdir -p "$TMPDIR/source/nested"
make_ipk "$TMPDIR/source/nested/luci-app-ssr-plus_1_all.ipk" "luci-app-ssr-plus" "xray-core, libustream-openssl, luci-i18n-ssr-plus-zh-cn"
make_ipk "$TMPDIR/source/luci-i18n-ssr-plus-zh-cn_1_all.ipk" "luci-i18n-ssr-plus-zh-cn"
make_ipk "$TMPDIR/source/xray-core_1_all.ipk" "xray-core" "ca-bundle"
make_ipk "$TMPDIR/source/libustream-openssl20201210_1_all.ipk" "libustream-openssl20201210" "libopenssl3, libubox20240329" "libustream-openssl"
make_ipk "$TMPDIR/source/ca-bundle_1_all.ipk" "ca-bundle"
make_ipk "$TMPDIR/source/libopenssl3_1_all.ipk" "libopenssl3"
make_ipk "$TMPDIR/source/libubox20240329_1_all.ipk" "libubox20240329"

output=$(bash "$TARGET_SCRIPT" "$TMPDIR/source")

printf '%s\n' "$output" | grep -q "Staged package files: 7"
printf '%s\n' "$output" | grep -q "SSR Plus directory files: 7"
printf '%s\n' "$output" | grep -q "libustream-openssl20201210_1_all.ipk"
printf '%s\n' "$output" | grep -q "All direct dependencies satisfied within staged SSR Plus set."

echo "test_verify_ssrplus_dry_run: ok"
