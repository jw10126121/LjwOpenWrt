#!/bin/bash

# 说明：验证 diy_config.sh 中 apk / ipk 的核心兼容逻辑：
# 1. .config 包管理器相关开关会按模式切换；
# 2. 运行时 feed 修补命令会指向正确的 apk/opkg 配置文件；
# 3. default-settings-chn 不再由包管理器切换逻辑直接控制。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

TMPDIR=$(mktemp -d)
TEST_BIN="$TMPDIR/test-bin"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TEST_BIN"
cat > "$TEST_BIN/sed" <<'EOF'
#!/bin/sh

if [ "$1" = "-i" ]; then
	shift
	exec /usr/bin/sed -i '' "$@"
fi

exec /usr/bin/sed "$@"
EOF
chmod +x "$TEST_BIN/sed"

extract_function() {
	local function_name=$1
	awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT"
}

FUNCTIONS_FILE="$TMPDIR/functions.sh"
{
	extract_function "set_kconfig_value"
	echo
	extract_function "build_disable_feed_cmd"
	echo
	extract_function "configure_package_manager_mode"
} > "$FUNCTIONS_FILE"

run_case() {
	local mode=$1
	local case_dir="$TMPDIR/$mode"
	local config_path="$case_dir/.config"

	mkdir -p "$case_dir"
cat > "$config_path" <<'EOF'
CONFIG_PKG_FORMAT=ipk
CONFIG_USE_APK=n
CONFIG_PACKAGE_luci-app-opkg=y
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y
EOF

	(
		op_config="$config_path"
		package_manager="$mode"
		PATH="$TEST_BIN:$PATH"
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_package_manager_mode >/dev/null
		build_disable_feed_cmd "openwrt_sqm_scripts_nss"
	) > "$case_dir/feed_cmd.txt"
}

run_case apk
run_case ipk

APK_CONFIG="$TMPDIR/apk/.config"
APK_FEED_CMD="$TMPDIR/apk/feed_cmd.txt"
IPK_CONFIG="$TMPDIR/ipk/.config"
IPK_FEED_CMD="$TMPDIR/ipk/feed_cmd.txt"

grep -q '^CONFIG_USE_APK=y$' "$APK_CONFIG"
grep -q '^CONFIG_PKG_FORMAT=apk$' "$APK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-app-package-manager=y$' "$APK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y$' "$APK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-app-opkg=n$' "$APK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-lib-ipkg=n$' "$APK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=n$' "$APK_CONFIG"
grep -q '/etc/apk/repositories.d/distfeeds.list' "$APK_FEED_CMD"
if grep -q '/etc/opkg/distfeeds.conf' "$APK_FEED_CMD"; then
	echo "apk mode should not point to opkg distfeeds" >&2
	exit 1
fi

grep -q '^CONFIG_USE_APK=n$' "$IPK_CONFIG"
grep -q '^CONFIG_PKG_FORMAT=ipk$' "$IPK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-app-package-manager=n$' "$IPK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=n$' "$IPK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-app-opkg=y$' "$IPK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-lib-ipkg=y$' "$IPK_CONFIG"
grep -q '^CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y$' "$IPK_CONFIG"
if grep -q '^CONFIG_PACKAGE_default-settings-chn=' "$APK_CONFIG"; then
	echo "package manager toggle should not touch default-settings-chn in apk mode" >&2
	exit 1
fi
if grep -q '^CONFIG_PACKAGE_default-settings-chn=' "$IPK_CONFIG"; then
	echo "package manager toggle should not touch default-settings-chn in ipk mode" >&2
	exit 1
fi
grep -q '/etc/opkg/distfeeds.conf' "$IPK_FEED_CMD"
if grep -q '/etc/apk/repositories.d/distfeeds.list' "$IPK_FEED_CMD"; then
	echo "ipk mode should not point to apk repositories" >&2
	exit 1
fi

echo "test_diy_config_package_manager: ok"
