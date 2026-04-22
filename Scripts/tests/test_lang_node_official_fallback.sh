#!/bin/bash

# 说明：验证 Packages.sh 外层在 sbwml 预编译 helper 失败时，
# 会保留官方 feeds/packages/lang/node 不变，并继续返回成功。

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PACKAGES_SCRIPT="$SCRIPT_DIR/Packages.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_ROOT="$TMPDIR/openwrt"
MOCK_SCRIPT_ROOT="$TMPDIR/mock-scripts"
FUNCTIONS_FILE="$TMPDIR/apply_lang_node_prebuilt_fix.sh"

mkdir -p "$OPENWRT_ROOT/feeds/packages/lang/node" "$MOCK_SCRIPT_ROOT/lib"
printf 'official-node\n' > "$OPENWRT_ROOT/feeds/packages/lang/node/SOURCE.txt"

cat > "$MOCK_SCRIPT_ROOT/lib/lang_node_prebuilt.sh" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$MOCK_SCRIPT_ROOT/lib/lang_node_prebuilt.sh"

awk '
	/^apply_lang_node_prebuilt_fix\(\) \{/ { in_func=1 }
	in_func { print }
	in_func && /^}/ { exit }
' "$PACKAGES_SCRIPT" > "$FUNCTIONS_FILE"

# shellcheck source=/dev/null
. "$FUNCTIONS_FILE"

current_script_dir="$MOCK_SCRIPT_ROOT"
openwrt_workdir="$OPENWRT_ROOT"

output=$(apply_lang_node_prebuilt_fix 2>&1)

printf '%s\n' "$output" | grep -Fq '【Lin】尝试使用 sbwml/feeds_packages_lang_node-prebuilt 加速 lang_node 编译'
printf '%s\n' "$output" | grep -Fq '【Lin】未命中可用的 sbwml lang_node 预编译分支，继续使用官方 lang/node'
grep -Fxq 'official-node' "$OPENWRT_ROOT/feeds/packages/lang/node/SOURCE.txt"
[ ! -d "$OPENWRT_ROOT/feeds/packages/lang/node.bak" ] || {
	echo "Official lang/node should remain untouched when the sbwml helper fails" >&2
	exit 1
}

echo "test_lang_node_official_fallback: ok"
