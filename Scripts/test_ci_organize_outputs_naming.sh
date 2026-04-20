#!/bin/bash

# 说明：整理后的上传文件名应带源码风味、FW 类型和 FRP 类型，便于快速区分配置。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/ci_organize_outputs.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/config_mine" "$OPENWRT_PATH/bin/packages" "$OPENWRT_PATH/bin/targets/qualcommax/ipq60xx"
TEST_BIN="$TMPDIR/test-bin"
mkdir -p "$TEST_BIN"

cat > "$TEST_BIN/tar" <<'EOF'
#!/bin/sh

args=""
skip_next=0
for arg in "$@"; do
	if [ "$skip_next" = "1" ]; then
		skip_next=0
		continue
	fi
	if [ "$arg" = "--transform" ]; then
		skip_next=1
		continue
	fi
	args="$args '$arg'"
done

eval "exec /usr/bin/tar $args"
EOF
chmod +x "$TEST_BIN/tar"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_PACKAGE_luci-app-accesscontrol=y
EOF

cat > "$OPENWRT_PATH/my_config.txt" <<'EOF'
CONFIG_TEST=y
EOF

touch "$OPENWRT_PATH/bin/targets/qualcommax/ipq60xx/openwrt-qualcommax-ipq60xx-cmiot_ax18-squashfs-sysupgrade.bin"

GITHUB_WORKSPACE="$TMPDIR/workspace"
mkdir -p "$GITHUB_WORKSPACE"
cp -R "$SCRIPT_DIR" "$GITHUB_WORKSPACE/Scripts"
GITHUB_ENV="$TMPDIR/github_env.txt"
GITHUB_OUTPUT="$TMPDIR/github_output.txt"
: > "$GITHUB_ENV"
: > "$GITHUB_OUTPUT"

OPENWRT_PATH="$OPENWRT_PATH" \
GITHUB_WORKSPACE="$GITHUB_WORKSPACE" \
GITHUB_ENV="$GITHUB_ENV" \
GITHUB_OUTPUT="$GITHUB_OUTPUT" \
WRT_DIR_SCRIPTS="Scripts" \
WRT_MINE_SAY="" \
system_content="支持设备：cmiot_ax18" \
SOURCE_FLAVOR_TAG="lean" \
FW_STACK_TAG="fw3" \
FRP_ROLE_TAG="frpc" \
BUILD_VARIANT_TAG="lean_fw3_frpc_ipk" \
DEVICE_SUBTARGET="ipq60xx" \
DEVICE_NAME_LIST="cmiot_ax18" \
DEVICE_NAME_LIST_LIAN="cmiot_ax18" \
WRT_VER="lede-master" \
START_TIME="D260419_T120000" \
PATH="$TEST_BIN:$PATH" \
bash "$TARGET_SCRIPT" >/dev/null

test -f "$OPENWRT_PATH/upload/config_lean_fw3_frpc_ipk_ipq60xx_cmiot_ax18_lede-master_D260419_T120000.txt"
test -f "$OPENWRT_PATH/upload/readme_lean_fw3_frpc_ipk_ipq60xx_cmiot_ax18_lede-master_D260419_T120000.txt"
test -f "$OPENWRT_PATH/upload/Packages_lean_fw3_frpc_ipk_ipq60xx_cmiot_ax18_lede-master_D260419_T120000.tar.gz"
test -f "$OPENWRT_PATH/upload/lean_fw3_frpc_ipk_ipq60xx_cmiot_ax18-squashfs-sysupgrade_lede-master_D260419_T120000.bin"

echo "test_ci_organize_outputs_naming: ok"
