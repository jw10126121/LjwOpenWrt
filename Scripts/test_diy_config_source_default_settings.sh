#!/bin/bash

# 说明：验证 default-settings-chn 只在 emortal 源码 + apk 模式下启用，
# 不再由 ipk/apk 切换逻辑直接绑定。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

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
	extract_function "configure_source_default_settings_package"
} > "$FUNCTIONS_FILE"

run_case() {
	local case_name=$1
	local mode=$2
	local source_layout=$3
	local case_dir="$TMPDIR/$case_name"
	local config_path="$case_dir/.config"

	mkdir -p "$case_dir/package"
	cat > "$config_path" <<'EOF'
CONFIG_USE_APK=n
EOF

	case "$source_layout" in
		emortal)
			mkdir -p "$case_dir/package/emortal/default-settings"
			: > "$case_dir/package/emortal/default-settings/Makefile"
			;;
		lean)
			mkdir -p "$case_dir/package/lean/default-settings"
			: > "$case_dir/package/lean/default-settings/Makefile"
			;;
	esac

	(
		cd "$case_dir"
		op_config="$config_path"
		package_manager="$mode"
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_source_default_settings_package >/dev/null
	)
}

run_case emortal_apk apk emortal
run_case emortal_ipk ipk emortal
run_case lean_apk apk lean

grep -q '^CONFIG_PACKAGE_default-settings-chn=y$' "$TMPDIR/emortal_apk/.config"
grep -q '^CONFIG_PACKAGE_default-settings-chn=n$' "$TMPDIR/emortal_ipk/.config"
grep -q '^CONFIG_PACKAGE_default-settings-chn=n$' "$TMPDIR/lean_apk/.config"

echo "test_diy_config_source_default_settings: ok"
