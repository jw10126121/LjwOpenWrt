#!/bin/bash

# 说明：验证 CORE-ALL workflow 已移除 DIY 包注入后的二次 feeds 刷新步骤，
# 并保持 diy Packages 之后直接进入 diy config。

set -eu

WORKFLOW_FILE="$(cd "$(dirname "$0")/.." && pwd)/.github/workflows/CORE-ALL.yml"
DIY_PACKAGES_LINE=$(grep -n '^    - name: diy Packages (自定义包)$' "$WORKFLOW_FILE" | cut -d: -f1)
DIY_CONFIG_LINE=$(grep -n '^    - name: diy config (自定义配置)$' "$WORKFLOW_FILE" | cut -d: -f1)

if grep -q '^    - name: Refresh Package Metadata After DIY Packages (刷新注入包后的元数据)$' "$WORKFLOW_FILE"; then
	echo "refresh-package-metadata step should be removed from CORE-ALL workflow" >&2
	exit 1
fi

[ -n "$DIY_PACKAGES_LINE" ]
[ -n "$DIY_CONFIG_LINE" ]
[ "$DIY_PACKAGES_LINE" -lt "$DIY_CONFIG_LINE" ]

echo "test_accesscontrol_config_refresh: ok"
