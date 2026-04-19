#!/bin/bash

# 说明：验证 readme.sh 与 ci_create_notifications.sh 的输出格式，重点覆盖失败/成功通知差异。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
README_SCRIPT="$SCRIPT_DIR/readme.sh"
NOTIFY_SCRIPT="$SCRIPT_DIR/ci_create_notifications.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

CONFIG_FILE="$TMPDIR/.config"
README_FILE="$TMPDIR/readme.txt"
ENV_FILE="$TMPDIR/github_env.txt"
OUTPUT_FILE="$TMPDIR/github_output.txt"

cat > "$CONFIG_FILE" <<'EOF'
CONFIG_PACKAGE_luci-app-accesscontrol=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-ddns=m
EOF

system_desc=$(cat <<'EOF'
编译开始：D260418_T105727

### --- 编译说明 --- ###
支持设备：glinet_gl-mt6000
固件类型：[常规版]
支持平台：mediatek-filogic
FW环境：FW3
FRP角色：FRPC
设备架构：aarch64_cortex-a53
内核版本：6.12.80
LUCI版本：23.05
OP版本：24.10.5
包管理器：ipkg
默认地址：192.168.0.1
默认密码：无 | password
是否wifi：有WIFI
源码地址：https://github.com/coolsnowwolf/lede
源码分支：master
源码hash：ecec1ef93a8920f30ef927d989b13b674d614ca6
EOF
)

# 先验证 README 生成逻辑，再验证 GitHub Actions 通知内容。
bash "$README_SCRIPT" -c "$CONFIG_FILE" -o "$README_FILE" -s "$system_desc" -r false

grep -q '^### --- 编译说明 --- ###$' "$README_FILE"
grep -q '^支持设备：glinet_gl-mt6000$' "$README_FILE"
grep -q '^FW环境：FW3$' "$README_FILE"
grep -q '^FRP角色：FRPC$' "$README_FILE"
grep -q '^#### --- 集成的插件 --- ####$' "$README_FILE"
grep -q '^luci-app-accesscontrol$' "$README_FILE"
grep -q '^luci-app-adguardhome$' "$README_FILE"
grep -q '^#### --- 安装包插件 --- ####$' "$README_FILE"
grep -q '^luci-app-ddns$' "$README_FILE"
grep -q '^编译开始：D260418_T105727$' "$README_FILE"

start_count=$(grep -c '^编译开始：D260418_T105727$' "$README_FILE")
[ "$start_count" -eq 1 ] || {
	echo "Expected exactly one compile start line in readme output" >&2
	exit 1
}

if grep -q '^编译完成：' "$README_FILE"; then
	echo "Unexpected compile end line in readme output" >&2
	exit 1
fi

DINGDING_MESSAGE="$(cat "$README_FILE")"
printf '%s\n' "$DINGDING_MESSAGE" | grep -q '^### --- 编译说明 --- ###$'
printf '%s\n' "$DINGDING_MESSAGE" | grep -q '^支持设备：glinet_gl-mt6000$'
printf '%s\n' "$DINGDING_MESSAGE" | grep -q '^FW环境：FW3$'
printf '%s\n' "$DINGDING_MESSAGE" | grep -q '^FRP角色：FRPC$'

: > "$ENV_FILE"
: > "$OUTPUT_FILE"
GITHUB_ENV="$ENV_FILE" \
GITHUB_OUTPUT="$OUTPUT_FILE" \
START_TIME="D260418_T105727" \
END_TIME="D260418_T120000" \
DEVICE_SUBTARGET="mt6000" \
GITHUB_REPOSITORY="user/repo" \
GITHUB_RUN_ID="123456" \
WRT_RELEASE_FIRMWARE="true" \
COMPILE_STATUS="failure" \
system_content="$system_desc" \
bash "$NOTIFY_SCRIPT"

grep -q '编译状态：failure' "$ENV_FILE"
grep -q '编译开始：D260418_T105727' "$ENV_FILE"
grep -q '编译结束：D260418_T120000' "$ENV_FILE"
if grep -q '下载地址：' "$ENV_FILE"; then
	echo "Unexpected download URL in failure notification" >&2
	exit 1
fi

: > "$ENV_FILE"
: > "$OUTPUT_FILE"
GITHUB_ENV="$ENV_FILE" \
GITHUB_OUTPUT="$OUTPUT_FILE" \
START_TIME="D260418_T105727" \
END_TIME="D260418_T120000" \
DEVICE_SUBTARGET="mt6000" \
GITHUB_REPOSITORY="user/repo" \
GITHUB_RUN_ID="123456" \
WRT_RELEASE_FIRMWARE="true" \
COMPILE_STATUS="success" \
system_content="$system_desc" \
bash "$NOTIFY_SCRIPT"

grep -q 'Release下载地址：https://github.com/user/repo/releases/tag/D260418_T105727_mt6000' "$ENV_FILE"
grep -q 'Artifact下载地址：https://github.com/user/repo/actions/runs/123456' "$ENV_FILE"
grep -q '编译状态：success' "$ENV_FILE"

echo "test_notification_format: ok"
