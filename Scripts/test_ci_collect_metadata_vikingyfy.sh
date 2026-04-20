#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SOURCE_SCRIPT="$SCRIPT_DIR/ci_collect_source_metadata.sh"
FINAL_SCRIPT="$SCRIPT_DIR/ci_collect_final_metadata.sh"
. "$SCRIPT_DIR/lib/source_flavor.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/target/linux/mediatek" "$OPENWRT_PATH/include"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=y
CONFIG_TARGET_ARCH_PACKAGES="aarch64_cortex-a53"
CONFIG_VERSION_NUMBER="SNAPSHOT"
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_frpc=y
CONFIG_PACKAGE_frps=m
EOF

cat > "$OPENWRT_PATH/target/linux/mediatek/Makefile" <<'EOF'
KERNEL_PATCHVER:=6.12
EOF

cat > "$OPENWRT_PATH/include/kernel-6.12" <<'EOF'
LINUX_KERNEL_HASH-6.12.80 = test
EOF

cat > "$OPENWRT_PATH/include/version.mk" <<'EOF'
VERSION_NUMBER:=$(if $(VERSION_NUMBER),$(VERSION_NUMBER),SNAPSHOT)
EOF

cat > "$OPENWRT_PATH/feeds.conf.default" <<'EOF'
src-git packages https://github.com/immortalwrt/packages.git
src-git luci https://github.com/immortalwrt/luci.git
EOF

selection="$(resolve_source_selection "VIKINGYFY" "")"
eval "$selection"

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_REPO_URL="$REPO_URL" \
WRT_REPO_BRANCH="$REPO_BRANCH" \
SOURCE_FLAVOR="$SOURCE_FLAVOR" \
WRT_IS_LEAN=false \
bash "$SOURCE_SCRIPT" > "$TMPDIR/source.env"

grep -q '^VERSION_KERNEL=6.12.80$' "$TMPDIR/source.env"

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_DEFAULT_LANIP="192.168.0.1" \
WRT_HAS_LITE=false \
WRT_HAS_WIFI=true \
WRT_REPO_URL="$REPO_URL" \
WRT_REPO_BRANCH="$REPO_BRANCH" \
WRT_SOURCE_FLAVOR="$SOURCE_FLAVOR" \
SOURCE_FLAVOR="$SOURCE_FLAVOR" \
DEVICE_TARGET="mediatek" \
DEVICE_SUBTARGET="filogic" \
DEVICE_PROFILE="glinet_gl-mt6000" \
VERSION_KERNEL="6.12.80" \
REPO_GIT_HASH="test-vikingyfy" \
bash "$FINAL_SCRIPT" > "$TMPDIR/final.env"

grep -q '^LUCI_VERSION=SNAPSHOT$' "$TMPDIR/final.env"
grep -q '^OP_VERSION=SNAPSHOT$' "$TMPDIR/final.env"
grep -q '^PACKAGE_MANAGER_TAG=ipk$' "$TMPDIR/final.env"
grep -q '^BUILD_VARIANT_TAG=vikingyfy_fw4_frpc_ipk$' "$TMPDIR/final.env"
grep -q '内核版本：6.12.80' "$TMPDIR/final.env"
grep -q 'LUCI版本：SNAPSHOT' "$TMPDIR/final.env"
grep -q 'OP版本：SNAPSHOT' "$TMPDIR/final.env"

echo "test_ci_collect_metadata_vikingyfy: ok"
