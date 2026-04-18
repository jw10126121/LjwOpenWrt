#!/bin/bash

# 说明：验证 lang_node 预编译替换逻辑，覆盖“按支持矩阵选择兼容分支成功”和“无兼容分支时保持原目录”两个场景。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/lib/lang_node_prebuilt.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

make_openwrt_tree() {
    local root_dir=$1
    local config_version=$2

    mkdir -p "$root_dir/include" "$root_dir/feeds/packages/lang/node"
    printf 'original-node\n' > "$root_dir/feeds/packages/lang/node/SOURCE.txt"
    cat > "$root_dir/.config" <<EOF
CONFIG_VERSION_NUMBER="${config_version}"
EOF
    cat > "$root_dir/include/version.mk" <<'EOF'
VERSION_NUMBER:=OpenWrt,24.10.9
EOF
    cat > "$root_dir/feeds.conf.default" <<'EOF'
src-git luci https://github.com/coolsnowwolf/luci;openwrt-24.10
EOF
}

make_prebuilt_repo() {
    local repo_dir=$1

    mkdir -p "$repo_dir"
    git init "$repo_dir" >/dev/null 2>&1
    git -C "$repo_dir" config user.name "Codex"
    git -C "$repo_dir" config user.email "codex@example.com"

    printf 'base\n' > "$repo_dir/SOURCE.txt"
    cat > "$repo_dir/Makefile" <<'EOF'
PKG_BASE:=packages-base
EOF
    git -C "$repo_dir" add SOURCE.txt Makefile
    git -C "$repo_dir" commit -m "base" >/dev/null 2>&1

    git -C "$repo_dir" checkout -b packages-24.10 >/dev/null 2>&1
    printf 'packages-24.10\n' > "$repo_dir/SOURCE.txt"
    cat > "$repo_dir/Makefile" <<'EOF'
PKG_BASE:=packages-23.05
EOF
    git -C "$repo_dir" add SOURCE.txt Makefile
    git -C "$repo_dir" commit -m "packages-24.10" >/dev/null 2>&1

    git -C "$repo_dir" checkout master >/dev/null 2>&1 || git -C "$repo_dir" checkout main >/dev/null 2>&1
}

WORKDIR_SUCCESS="$TMPDIR/openwrt-success"
REPO_DIR="$TMPDIR/prebuilt-repo"
make_openwrt_tree "$WORKDIR_SUCCESS" "24.10.1"
make_prebuilt_repo "$REPO_DIR"

LANG_NODE_PREBUILT_REPO="$REPO_DIR" \
bash "$TARGET_SCRIPT" "$WORKDIR_SUCCESS"

grep -Fxq 'packages-24.10' "$WORKDIR_SUCCESS/feeds/packages/lang/node/SOURCE.txt"
grep -Fxq 'PKG_BASE:=packages-24.10' "$WORKDIR_SUCCESS/feeds/packages/lang/node/Makefile"
[ ! -d "$WORKDIR_SUCCESS/feeds/packages/lang/node.bak" ] || {
    echo "Backup directory should be removed after successful replacement" >&2
    exit 1
}

WORKDIR_COMPAT="$TMPDIR/openwrt-compat"
make_openwrt_tree "$WORKDIR_COMPAT" "25.12.1"

LANG_NODE_PREBUILT_REPO="$REPO_DIR" \
bash "$TARGET_SCRIPT" "$WORKDIR_COMPAT"

grep -Fxq 'packages-24.10' "$WORKDIR_COMPAT/feeds/packages/lang/node/SOURCE.txt"
grep -Fxq 'PKG_BASE:=packages-24.10' "$WORKDIR_COMPAT/feeds/packages/lang/node/Makefile"
[ ! -d "$WORKDIR_COMPAT/feeds/packages/lang/node.bak" ] || {
    echo "Backup directory should be removed after compatible replacement" >&2
    exit 1
}

WORKDIR_ROLLBACK="$TMPDIR/openwrt-rollback"
make_openwrt_tree "$WORKDIR_ROLLBACK" "23.05.5"

if LANG_NODE_PREBUILT_REPO="$REPO_DIR" \
   LANG_NODE_SUPPORTED_PREBUILT_VERSIONS="24.10" \
   LANG_NODE_DEFAULT_FALLBACK_VERSION="" \
   bash "$TARGET_SCRIPT" "$WORKDIR_ROLLBACK"; then
    echo "Expected replacement to fail when no compatible branch exists" >&2
    exit 1
fi

grep -Fxq 'original-node' "$WORKDIR_ROLLBACK/feeds/packages/lang/node/SOURCE.txt"
[ ! -d "$WORKDIR_ROLLBACK/feeds/packages/lang/node.bak" ] || {
    echo "Backup directory should be removed after rollback" >&2
    exit 1
}

echo "test_lang_node_prebuilt: ok"
