#!/bin/bash

# 说明：
# 1. 按顺序合并多个基础配置文件，再拼接机型配置文件。
# 2. 基础配置文件列表由外层脚本固定生成。
# 3. 可选 overlay 配置会在最后追加，用于覆盖机型配置里的少量差异项。

set -eu

config_dir=${1:?config_dir is required}
general_configs=${2:?general_configs is required}
device_config=${3:?device_config is required}
overlay_config=''

case $# in
	4)
		output_config=${4:?output_config is required}
		;;
	5)
		overlay_config=${4:?overlay_config is required}
		output_config=${5:?output_config is required}
		;;
	*)
		echo "Usage: $0 <config_dir> <general_configs> <device_config> [overlay_config] <output_config>" >&2
		exit 1
		;;
esac

: > "$output_config"

for general_cfg in $general_configs; do
	config_path="$config_dir/$general_cfg"
	if [ ! -f "$config_path" ]; then
		echo "Missing general config: $config_path" >&2
		exit 1
	fi
	cat "$config_path" >> "$output_config"
done

device_config_path="$device_config"
if [ ! -f "$device_config_path" ]; then
	device_config_path="$config_dir/$device_config"
	if [ ! -f "$device_config_path" ]; then
		echo "Missing device config: $device_config_path" >&2
		exit 1
	fi
fi

cat "$device_config_path" >> "$output_config"

if [ -n "$overlay_config" ]; then
	overlay_config_path="$overlay_config"
	if [ ! -f "$overlay_config_path" ]; then
		overlay_config_path="$config_dir/$overlay_config"
		if [ ! -f "$overlay_config_path" ]; then
			echo "Missing overlay config: $overlay_config_path" >&2
			exit 1
		fi
	fi
	cat "$overlay_config_path" >> "$output_config"
fi
