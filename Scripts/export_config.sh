#!/bin/bash

# 说明：
# 1. 导出一份可直接分享的参数化合并配置文件。
# 2. 固定加载 GENERAL.txt + GENERAL-SERVICE.txt + GENERAL-FW3|FW4，再按 device / overlays 叠加。
# 3. overlay 支持多个同时叠加，按传入顺序覆盖。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_general_configs.sh"
MERGE_SCRIPT="$SCRIPT_DIR/merge_configs.sh"

config_dir='Config'
device=''
fw=''
overlay_list=''
output_config=''

show_help() {
	cat <<'EOF'
用法：
  bash Scripts/export_config.sh --device 设备名 --fw fw3|fw4 --output 输出文件 [--overlay 列表] [--config-dir 目录]

示例：
  bash Scripts/export_config.sh \
    --device IPQ60XX-NOWIFI \
    --fw fw3 \
    --overlay frps,apk \
    --output /tmp/IPQ60XX-NOWIFI-fw3-frps-apk.txt

参数：
  --device      设备名，例如 IPQ60XX-NOWIFI
  --fw          防火墙栈，fw3 或 fw4
  --overlay     可选 overlay 列表，逗号分隔，例如 frps,apk
  --output      输出文件路径
  --config-dir  配置目录，默认 Config
  -h, --help    显示帮助
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--device)
			device=${2:?missing value for --device}
			shift 2
			;;
		--fw)
			fw=${2:?missing value for --fw}
			shift 2
			;;
		--overlay)
			overlay_list=${2:?missing value for --overlay}
			shift 2
			;;
		--output)
			output_config=${2:?missing value for --output}
			shift 2
			;;
		--config-dir)
			config_dir=${2:?missing value for --config-dir}
			shift 2
			;;
		-h|--help)
			show_help
			exit 0
			;;
		*)
			echo "未知参数：$1" >&2
			show_help >&2
			exit 1
			;;
	esac
done

[ -n "$device" ] || {
	echo "缺少设备参数，请使用 --device。" >&2
	exit 1
}

[ -n "$output_config" ] || {
	echo "缺少输出路径，请使用 --output。" >&2
	exit 1
}

[ -n "$fw" ] || {
	echo "缺少防火墙参数，请使用 --fw。" >&2
	exit 1
}

case "${fw}" in
	fw3|fw4|FW3|FW4)
		;;
	*)
		echo "fw 参数只支持 fw3 或 fw4" >&2
		exit 1
		;;
esac

has_apk=false
has_ipk=false

if [ -n "$overlay_list" ]; then
	OLD_IFS=$IFS
	IFS=','
	set -- $overlay_list
	IFS=$OLD_IFS
	for overlay_name in "$@"; do
		overlay_name=$(printf '%s' "$overlay_name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
		[ -n "$overlay_name" ] || continue
		[ "$overlay_name" = 'apk' ] && has_apk=true
		[ "$overlay_name" = 'ipk' ] && has_ipk=true
	done
fi

if [ "$has_apk" = true ] && [ "$has_ipk" = true ]; then
	echo "overlay apk 与 ipk 不能同时启用" >&2
	exit 1
fi

resolved_general_configs=$(bash "$RESOLVE_SCRIPT" "$fw")

device_config="devices/${device}.txt"
if [ ! -f "$config_dir/$device_config" ]; then
	echo "缺少设备配置：$config_dir/$device_config" >&2
	exit 1
fi

device_overlay_config="device-overlays/${device}-$(printf '%s' "$fw" | tr '[:lower:]' '[:upper:]').txt"

bash "$MERGE_SCRIPT" \
	"$config_dir" \
	"$resolved_general_configs" \
	"$device_config" \
	"$output_config"

if [ -f "$config_dir/$device_overlay_config" ]; then
	cat "$config_dir/$device_overlay_config" >> "$output_config"
fi

if [ -n "$overlay_list" ]; then
	OLD_IFS=$IFS
	IFS=','
	set -- $overlay_list
	IFS=$OLD_IFS
		for overlay_name in "$@"; do
			overlay_name=$(printf '%s' "$overlay_name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
			[ -n "$overlay_name" ] || continue
			overlay_file="overlays/$(printf '%s' "$overlay_name" | tr '[:lower:]' '[:upper:]').txt"
			if [ ! -f "$config_dir/$overlay_file" ]; then
				echo "缺少 overlay 配置：$config_dir/$overlay_file" >&2
				exit 1
			fi
			cat "$config_dir/$overlay_file" >> "$output_config"
		done
fi

echo "导出完成：$output_config"
