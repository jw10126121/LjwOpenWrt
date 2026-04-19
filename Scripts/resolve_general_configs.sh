#!/bin/bash

# 说明：
# 1. 根据机型配置名自动选择基础配置组合。
# 2. 如果用户显式传入 WRT_GENERAL_CONFIG，则优先使用手工值。

set -eu

manual_general_configs=${1-}
wrt_config=${2:?wrt_config is required}

if [ -n "$manual_general_configs" ]; then
	printf '%s\n' "$manual_general_configs"
	exit 0
fi

case "$wrt_config" in
	*-FW4.txt|*-V.txt)
		printf '%s\n' 'GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt'
		;;
	*)
		printf '%s\n' 'GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt'
		;;
esac
