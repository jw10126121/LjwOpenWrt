#!/bin/bash

# 说明：workflow 与导出脚本不再暴露 WRT_GENERAL_CONFIG / --general 入口。

set -eu

if rtk rg -n "WRT_GENERAL_CONFIG" .github/workflows README.md Scripts/export_config.sh Scripts/resolve_general_configs.sh >/dev/null; then
	echo "WRT_GENERAL_CONFIG references should be removed from public entrypoints" >&2
	exit 1
fi

if rtk rg -n -- "--general" Scripts/export_config.sh README.md >/dev/null; then
	echo "--general option should be removed" >&2
	exit 1
fi

echo "test_no_general_config_input: ok"
