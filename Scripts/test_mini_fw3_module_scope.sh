#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

allowed_module_pattern='^CONFIG_PACKAGE_(luci-app-frps|luci-i18n-frps-zh-cn|frps)=m$'

check_file() {
	local file=$1
	local unexpected_modules

	unexpected_modules=$(
		sed 's/[[:space:]]*#.*$//' "$file" \
			| grep '^CONFIG_PACKAGE_.*=m$' \
			| grep -Ev "$allowed_module_pattern" || true
	)
	if [ -n "$unexpected_modules" ]; then
		echo "发现不应保留的 MINI 模块包：$file" >&2
		printf '%s\n' "$unexpected_modules" >&2
		exit 1
	fi

	sed 's/[[:space:]]*#.*$//' "$file" | grep -q '^CONFIG_PACKAGE_luci-app-frpc=y$'
	sed 's/[[:space:]]*#.*$//' "$file" | grep -q '^CONFIG_PACKAGE_luci-app-frps=m$'
}

check_file "$REPO_ROOT/Config/IPQ60XX-NOWIFI-FW3-MINI.txt"
check_file "$REPO_ROOT/Config/MT6000-WIFI-FW3-MINI.txt"

echo "test_mini_fw3_module_scope: ok"
