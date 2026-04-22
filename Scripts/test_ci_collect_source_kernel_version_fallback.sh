#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SOURCE_SCRIPT="$SCRIPT_DIR/ci_collect_source_metadata.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/target/linux/qualcommax" "$OPENWRT_PATH/include"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y
EOF

cat > "$OPENWRT_PATH/target/linux/qualcommax/Makefile" <<'EOF'
KERNEL_PATCHVER:=6.12
EOF

cat > "$OPENWRT_PATH/include/version.mk" <<'EOF'
VERSION_NUMBER:= OpenWrt, 24.10.5
EOF

cat > "$OPENWRT_PATH/feeds.conf.default" <<'EOF'
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
EOF

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_REPO_URL="https://github.com/example/openwrt" \
WRT_REPO_BRANCH="main" \
bash "$SOURCE_SCRIPT" > "$TMPDIR/source.env"

grep -q '^VERSION_KERNEL=6.12$' "$TMPDIR/source.env"

echo "test_ci_collect_source_kernel_version_fallback: ok"
