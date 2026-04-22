#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/ci_collect_source_metadata.sh"
. "$SCRIPT_DIR/lib/source_flavor.sh"

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

selection="$(resolve_source_selection "")"
eval "$selection"

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_REPO_URL="$REPO_URL" \
WRT_REPO_BRANCH="$REPO_BRANCH" \
SOURCE_FLAVOR="$SOURCE_FLAVOR" \
bash "$TARGET_SCRIPT" > "$TMPDIR/meta.env"

grep -q '^SOURCE_FLAVOR=lean$' "$TMPDIR/meta.env"

echo "test_ci_collect_source_metadata: ok"
