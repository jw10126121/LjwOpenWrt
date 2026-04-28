#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/ci_collect_source_metadata.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/target/linux/qualcommax" "$OPENWRT_PATH/target/linux/generic"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y
EOF

cat > "$OPENWRT_PATH/target/linux/qualcommax/Makefile" <<'EOF'
KERNEL_PATCHVER:=6.1
EOF

cat > "$OPENWRT_PATH/target/linux/generic/kernel-6.1" <<'EOF'
LINUX_KERNEL_HASH-6.1.42:=dummy
EOF

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_REPO_URL="https://github.com/coolsnowwolf/lede" \
WRT_REPO_BRANCH="master" \
bash "$TARGET_SCRIPT" > "$TMPDIR/meta.env"

if grep -q '^SOURCE_FLAVOR=' "$TMPDIR/meta.env"; then
    echo "SOURCE_FLAVOR should no longer be emitted" >&2
    exit 1
fi

echo "test_ci_collect_source_metadata: ok"
