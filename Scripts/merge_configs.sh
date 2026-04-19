#!/bin/bash

# 说明：
# 1. 按顺序合并多个基础配置文件，再拼接机型配置文件。
# 2. `WRT_GENERAL_CONFIG` 支持空格分隔多个文件名。

set -eu

config_dir=${1:?config_dir is required}
general_configs=${2:?general_configs is required}
device_config=${3:?device_config is required}
output_config=${4:?output_config is required}

: > "$output_config"

for general_cfg in $general_configs; do
	config_path="$config_dir/$general_cfg"
	if [ ! -f "$config_path" ]; then
		echo "Missing general config: $config_path" >&2
		exit 1
	fi
	cat "$config_path" >> "$output_config"
done

device_config_path="$config_dir/$device_config"
if [ ! -f "$device_config_path" ]; then
	echo "Missing device config: $device_config_path" >&2
	exit 1
fi

cat "$device_config_path" >> "$output_config"
