#!/bin/bash

# 说明：
# 1. 根据防火墙参数选择固定的基础配置组合。
# 2. GENERAL / GENERAL-SERVICE / GENERAL-FW3|FW4 始终作为统一底座加载。

set -eu

fw_selector=${1:?fw_selector is required}

case "${fw_selector}" in
	fw4|FW4|*-FW4.txt)
		printf '%s\n' 'GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt'
		;;
	*)
		printf '%s\n' 'GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt'
		;;
esac
