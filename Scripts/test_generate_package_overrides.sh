#!/bin/bash

# 说明：为 generate_package_overrides.sh 构造最小可复现样例，验证动态依赖分组文本是否正确生成。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GENERATE_SCRIPT="$SCRIPT_DIR/generate_package_overrides.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

make_ipk() {
	# 生成一个最小 ipk，便于在纯 shell 测试里模拟依赖图。
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

PACKAGE_DIR="$TMPDIR/packages"
CONFIG_FILE="$TMPDIR/.config"
OVERRIDES_FILE="$TMPDIR/generated_overrides.txt"
mkdir -p "$PACKAGE_DIR"

make_ipk "$PACKAGE_DIR/luci-app-demo_1_all.ipk" "luci-app-demo" "demo-core, libc"
make_ipk "$PACKAGE_DIR/luci-i18n-demo-zh-cn_1_all.ipk" "luci-i18n-demo-zh-cn"
make_ipk "$PACKAGE_DIR/demo-core_1_all.ipk" "demo-core" "demo-helper, libpthread"
make_ipk "$PACKAGE_DIR/demo-helper_1_all.ipk" "demo-helper"
make_ipk "$PACKAGE_DIR/luci-app-basic_1_all.ipk" "luci-app-basic" "libc"
make_ipk "$PACKAGE_DIR/luci-i18n-basic-zh-cn_1_all.ipk" "luci-i18n-basic-zh-cn"

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-demo=m
CONFIG_PACKAGE_luci-app-basic=m
EOF

# 只校验动态规则文本生成结果；Organize_Packages.sh 是否消费这些规则由其自身测试负责。
bash "$GENERATE_SCRIPT" "$PACKAGE_DIR" "$CONFIG_FILE" "$OVERRIDES_FILE"

grep -q '^luci-app-demo|luci-app-demo_ luci-i18n-demo-zh-cn_ demo-core_ demo-helper_$' "$OVERRIDES_FILE"
if grep -q '^luci-app-basic|' "$OVERRIDES_FILE"; then
	echo "Unexpected override generated for luci-app-basic" >&2
	exit 1
fi

echo "test_generate_package_overrides: ok"
