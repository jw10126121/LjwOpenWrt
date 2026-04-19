#!/bin/bash

# 说明：为 diy_config.sh 的中度重构固定函数边界，避免职责再次混杂回主流程。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

required_functions='
resolve_source_flavor_from_input
configure_common_system_defaults
configure_source_default_settings_package
append_default_settings_snippet
apply_lean_runtime_customizations
apply_VIKINGYFY_runtime_customizations
patch_apk_empty_feed_indexing
apply_generic_runtime_defaults
apply_ipq_optimizations
apply_ipq_init_tuning
main
'

for fn in $required_functions; do
	if ! grep -q "^${fn}() {" "$TARGET_SCRIPT"; then
		echo "Missing expected function: $fn" >&2
		exit 1
	fi
done

echo "test_diy_config_structure: ok"
