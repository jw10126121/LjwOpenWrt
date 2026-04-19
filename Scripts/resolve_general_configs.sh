#!/bin/bash

# 说明：
# 1. 根据防火墙参数选择基础配置组合。
# 2. 兼容旧的设备配置文件名输入，便于重构过程中过渡。
# 3. 如果用户显式传入 WRT_GENERAL_CONFIG，则优先使用手工值。

set -eu

manual_general_configs=${1-}
fw_selector=${2:?fw_selector is required}

if [ -n "$manual_general_configs" ]; then
	printf '%s\n' "$manual_general_configs"
	exit 0
fi

case "${fw_selector}" in
	fw4|FW4|*-FW4.txt)
		printf '%s\n' 'GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt'
		;;
	*)
		printf '%s\n' 'GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt'
		;;
esac
