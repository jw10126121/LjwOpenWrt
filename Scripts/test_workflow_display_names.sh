#!/bin/bash

# 说明：默认入口 workflow 的外层显示名应直接体现源码风味、防火墙栈和 overlays。

set -eu

for workflow in .github/workflows/DEFAULT.yml .github/workflows/CUSTOM.yml; do
	line=$(grep -n 'name: \$' "$workflow" | head -n 1 | cut -d: -f2- || true)
	printf '%s\n' "$line" | grep -q 'inputs.WRT_SOURCE_FLAVOR'
	printf '%s\n' "$line" | grep -q 'inputs.WRT_DEVICE'
	printf '%s\n' "$line" | grep -q 'inputs.WRT_FIREWALL'
	printf '%s\n' "$line" | grep -q 'inputs.WRT_OVERLAYS'
done

echo "test_workflow_display_names: ok"
