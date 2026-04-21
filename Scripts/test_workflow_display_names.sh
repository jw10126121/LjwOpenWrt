#!/bin/bash

# 说明：DEFAULT 的外层显示名继续体现源码风味、防火墙栈和 overlays；
# CUSTOM 改成固定预设入口后，不再依赖 dispatch inputs 生成显示名。

set -eu

default_line=$(grep -n 'name: \$' .github/workflows/DEFAULT.yml | head -n 1 | cut -d: -f2- || true)
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_SOURCE_FLAVOR'
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_DEVICE'
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_FIREWALL'
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_OVERLAYS'
grep -q 'WRT_LUCI_BRANCH:' .github/workflows/DEFAULT.yml

if grep -n 'name: \$' .github/workflows/CUSTOM.yml | head -n 1 | cut -d: -f2- | grep -q 'inputs.WRT_'; then
	echo "CUSTOM workflow name should not depend on dispatch inputs" >&2
	exit 1
fi

echo "test_workflow_display_names: ok"
