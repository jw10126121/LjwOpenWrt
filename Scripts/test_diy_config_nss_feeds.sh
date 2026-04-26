#!/bin/bash

# 说明：lean 成为唯一源码后，NSS 相关 feed 开关应始终关闭。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
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
	extract_function "configure_nss_feed_options"
	echo
	extract_function "configure_base_package_options"
} > "$FUNCTIONS_FILE"

run_case() {
	local target_name=$1
	local source_flavor=$2
	local case_dir="$TMPDIR/${target_name}_${source_flavor}"
	local config_path="$case_dir/.config"

	mkdir -p "$case_dir"
	cat > "$config_path" <<'EOF'
CONFIG_PACKAGE_luci=n
CONFIG_LUCI_LANG_zh_Hans=n
CONFIG_FEED_helloworld=y
EOF

	(
		op_config="$config_path"
		WRT_TARGET="$target_name"
		source_flavor="$source_flavor"
		package_manager='ipk'
		PATH="$TEST_BIN:$PATH"
		configure_package_manager_mode() { :; }
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_base_package_options >/dev/null
	)
}

run_case IPQ60XX-NOWIFI-FW3 lean
run_case MT6000-WIFI-FW4 lean

grep -q '^CONFIG_FEED_helloworld=n$' "$TMPDIR/IPQ60XX-NOWIFI-FW3_lean/.config"
grep -q '^CONFIG_FEED_sqm_scripts_nss=n$' "$TMPDIR/IPQ60XX-NOWIFI-FW3_lean/.config"
grep -q '^CONFIG_FEED_nss_packages=n$' "$TMPDIR/IPQ60XX-NOWIFI-FW3_lean/.config"

grep -q '^CONFIG_FEED_helloworld=n$' "$TMPDIR/MT6000-WIFI-FW4_lean/.config"
grep -q '^CONFIG_FEED_sqm_scripts_nss=n$' "$TMPDIR/MT6000-WIFI-FW4_lean/.config"
grep -q '^CONFIG_FEED_nss_packages=n$' "$TMPDIR/MT6000-WIFI-FW4_lean/.config"

echo "test_diy_config_nss_feeds: ok"
