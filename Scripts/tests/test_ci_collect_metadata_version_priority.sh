#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
FINAL_SCRIPT="$SCRIPT_DIR/ci_collect_final_metadata.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

make_openwrt_tree() {
    local root_dir=$1
    local config_version=$2
    local include_version_line=$3
    local feeds_content=$4
    local firewall_mode=${5:-fw4}

    mkdir -p "$root_dir"

    local firewall_line='CONFIG_PACKAGE_firewall=n'
    local firewall4_line='CONFIG_PACKAGE_firewall4=y'
    case "$firewall_mode" in
        fw3)
            firewall_line='CONFIG_PACKAGE_firewall=y'
            firewall4_line='CONFIG_PACKAGE_firewall4=n'
            ;;
        mixed)
            firewall_line='CONFIG_PACKAGE_firewall=y'
            firewall4_line='CONFIG_PACKAGE_firewall4=y'
            ;;
    esac

    cat > "$root_dir/.config" <<EOF
CONFIG_TARGET_ARCH_PACKAGES="aarch64_cortex-a53"
CONFIG_VERSION_NUMBER="${config_version}"
${firewall_line}
${firewall4_line}
CONFIG_PACKAGE_frpc=y
CONFIG_PACKAGE_frps=m
EOF

    cat > "$root_dir/include.version.mk" <<EOF
${include_version_line}
EOF

    cat > "$root_dir/feeds.conf.default" <<EOF
${feeds_content}
EOF
}

run_case() {
    local root_dir=$1
    local output_file=$2

    OPENWRT_PATH="$root_dir" \
    WRT_DEFAULT_LANIP="192.168.0.1" \
    WRT_HAS_LITE=false \
    WRT_HAS_WIFI=true \
    WRT_REPO_URL="https://github.com/example/openwrt" \
    WRT_REPO_BRANCH="main" \
    SOURCE_FLAVOR="lean" \
    DEVICE_TARGET="qualcommax" \
    DEVICE_SUBTARGET="ipq60xx" \
    DEVICE_PROFILE="cmiot_ax18" \
    VERSION_KERNEL="6.12.80" \
    REPO_GIT_HASH="test-hash" \
    bash "$FINAL_SCRIPT" > "$output_file"
}

CASE_DIR="$TMPDIR/snapshot-config-release-include"
make_openwrt_tree \
    "$CASE_DIR" \
    "SNAPSHOT" \
    "VERSION_NUMBER:= OpenWrt, 24.10.5" \
    "src-git luci https://github.com/coolsnowwolf/luci.git"

mv "$CASE_DIR/include.version.mk" "$CASE_DIR/version.mk.tmp"
mkdir -p "$CASE_DIR/include"
mv "$CASE_DIR/version.mk.tmp" "$CASE_DIR/include/version.mk"

run_case "$CASE_DIR" "$TMPDIR/case1.env"

grep -q '^OP_VERSION=24.10.5$' "$TMPDIR/case1.env"
grep -q '^LUCI_VERSION=24.10.5$' "$TMPDIR/case1.env"
grep -q '^PACKAGE_MANAGER_TAG=ipk$' "$TMPDIR/case1.env"
grep -q '^BUILD_VARIANT_TAG=lean_fw4_frpc_ipk$' "$TMPDIR/case1.env"

CASE_DIR2="$TMPDIR/explicit-luci-branch"
make_openwrt_tree \
    "$CASE_DIR2" \
    "OpenWrt 24.10.5" \
    "VERSION_NUMBER:= OpenWrt, 24.10.5" \
    "src-git luci https://github.com/openwrt/luci.git;openwrt-23.05"

mv "$CASE_DIR2/include.version.mk" "$CASE_DIR2/version.mk.tmp"
mkdir -p "$CASE_DIR2/include"
mv "$CASE_DIR2/version.mk.tmp" "$CASE_DIR2/include/version.mk"

run_case "$CASE_DIR2" "$TMPDIR/case2.env"

grep -q '^OP_VERSION=24.10.5$' "$TMPDIR/case2.env"
grep -q '^LUCI_VERSION=23.05$' "$TMPDIR/case2.env"
grep -q '^BUILD_VARIANT_TAG=lean_fw4_frpc_ipk$' "$TMPDIR/case2.env"

CASE_DIR3="$TMPDIR/mixed-fw-stack"
make_openwrt_tree \
    "$CASE_DIR3" \
    "OpenWrt 24.10.5" \
    "VERSION_NUMBER:= OpenWrt, 24.10.5" \
    "src-git luci https://github.com/openwrt/luci.git;openwrt-23.05" \
    "mixed"

mv "$CASE_DIR3/include.version.mk" "$CASE_DIR3/version.mk.tmp"
mkdir -p "$CASE_DIR3/include"
mv "$CASE_DIR3/version.mk.tmp" "$CASE_DIR3/include/version.mk"

run_case "$CASE_DIR3" "$TMPDIR/case3.env"

grep -q '^FW_STACK_TAG=mixed$' "$TMPDIR/case3.env"
grep -q 'FW环境：FW3+FW4(冲突)' "$TMPDIR/case3.env"
grep -q '^BUILD_VARIANT_TAG=lean_mixed_frpc_ipk$' "$TMPDIR/case3.env"

echo "test_ci_collect_metadata_version_priority: ok"
