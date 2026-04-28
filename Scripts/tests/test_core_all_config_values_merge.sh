#!/bin/bash

# 说明：验证 CORE-ALL 已删除二次 checkout，
# 并把 START_DATE / START_TIME 合并到 Check Config Values 步骤中设置。

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"

count=$(grep -c 'uses: actions/checkout@' "$workflow_file")
[ "$count" -eq 1 ] || {
	echo "CORE-ALL should only keep one checkout step" >&2
	exit 1
}

if grep -q '^    - name: Check Values (设置编译变量)$' "$workflow_file"; then
	echo "Check Values step should be merged into Check Config Values" >&2
	exit 1
fi

config_block=$(awk '
/^    - name: Check Config Values \(检查配置变量\)$/ { in_block=1 }
in_block { print }
in_block && NR != 1 && /^    - name: / && $0 != "    - name: Check Config Values (检查配置变量)" { exit }
' "$workflow_file")

printf '%s\n' "$config_block" | grep -q 'START_DATE=$(date +"D%y%m%d")'
printf '%s\n' "$config_block" | grep -q 'START_TIME=$(date +"D%y%m%d_T%H%M%S")'
printf '%s\n' "$config_block" | grep -q 'echo "START_DATE=$START_DATE" >> $GITHUB_ENV'
printf '%s\n' "$config_block" | grep -q 'echo "START_TIME=$START_TIME" >> $GITHUB_ENV'

echo "test_core_all_config_values_merge: ok"
