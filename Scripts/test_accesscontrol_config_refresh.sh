#!/bin/bash

# 说明：验证 CORE-ALL workflow 会在注入 DIY 包之后刷新 feeds/package 索引，
# 避免像 luci-app-accesscontrol 这类后补包在最终 defconfig 中缺失。

set -eu

WORKFLOW_FILE="$(cd "$(dirname "$0")/.." && pwd)/.github/workflows/CORE-ALL.yml"
TMPDIR=$(mktemp -d)

cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

extract_step() {
	local step_name="$1"
	local output_file="$2"

	awk -v target="    - name: ${step_name}" '
		$0 == target {
			in_block=1
		}
		in_block {
			print
		}
		in_block && NR != 1 && $0 ~ /^    - name: / && $0 != target {
			exit
		}
	' "$WORKFLOW_FILE" | sed '${/^    - name: /d;}' > "$output_file"

	[ -s "$output_file" ] || {
		echo "missing step: ${step_name}" >&2
		exit 1
	}
}

extract_step "diy Packages (自定义包)" "$TMPDIR/diy-packages.txt"
extract_step "Refresh Package Metadata After DIY Packages (刷新注入包后的元数据)" "$TMPDIR/refresh-package-metadata.txt"
extract_step "diy config (自定义配置)" "$TMPDIR/diy-config.txt"

REFRESH_STEP="$TMPDIR/refresh-package-metadata.txt"
grep -q 'rm -f ./tmp/.packageinfo ./tmp/.packagedeps ./tmp/.packageauxvars' "$REFRESH_STEP"
grep -q './scripts/feeds install -a' "$REFRESH_STEP"

DIY_PACKAGES_LINE=$(grep -n '^    - name: diy Packages (自定义包)$' "$WORKFLOW_FILE" | cut -d: -f1)
REFRESH_LINE=$(grep -n '^    - name: Refresh Package Metadata After DIY Packages (刷新注入包后的元数据)$' "$WORKFLOW_FILE" | cut -d: -f1)
DIY_CONFIG_LINE=$(grep -n '^    - name: diy config (自定义配置)$' "$WORKFLOW_FILE" | cut -d: -f1)

[ "$DIY_PACKAGES_LINE" -lt "$REFRESH_LINE" ]
[ "$REFRESH_LINE" -lt "$DIY_CONFIG_LINE" ]

echo "test_accesscontrol_config_refresh: ok"
