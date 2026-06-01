#!/bin/bash

# 说明：
# 1. 导出一份可直接分享的参数化合并配置文件。
# 2. 固定加载 GENERAL.txt，再按需要叠加设备主配置、device-overlay 与 overlays。
# 3. overlay 支持多个同时叠加，按传入顺序覆盖。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MERGE_SCRIPT="$SCRIPT_DIR/merge_configs.sh"
OVERLAY_UTILS="$SCRIPT_DIR/lib/overlay_utils.sh"

. "$OVERLAY_UTILS"

config_dir='Config'
device=''
fw=''
overlay_list=''
output_config=''
cleanup_files=''

resolve_device_config() {
	local config_root=$1
	local device_name=$2

	# 优先查找无后缀的基线文件
	if [ -f "$config_root/${device_name}.txt" ]; then
		printf '%s\n' "${device_name}.txt"
		return 0
	fi

	# 兼容旧文件名（过渡期，迁移完成后可移除）
	if [ -f "$config_root/${device_name}-FW3.txt" ]; then
		printf '%s\n' "${device_name}-FW3.txt"
		return 0
	fi

	return 1
}

cleanup() {
	if [ -n "$cleanup_files" ]; then
		rm -f $cleanup_files
	fi
}

device_config_embeds_fw_stack() {
	local config_path=$1

	grep -Eq '^# >>> FW[34]-BEGIN$' "$config_path"
}

device_config_embeds_service_layer() {
	local config_path=$1

	grep -Eq '^# >>> SERVICE-BEGIN$' "$config_path"
}

preprocess_device_config() {
	local input_config=$1
	local fw_name=$2
	local output_config_path=$3
	local current_block=''
	local fw_upper line

	fw_upper=$(printf '%s' "$fw_name" | tr '[:lower:]' '[:upper:]')
	: > "$output_config_path"

	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			'# >>> FW3-BEGIN')
				current_block='FW3'
				continue
				;;
			'# <<< FW3-END')
				current_block=''
				continue
				;;
			'# >>> SERVICE-BEGIN')
				current_block='SERVICE'
				continue
				;;
			'# <<< SERVICE-END')
				current_block=''
				continue
				;;
			'# >>> FW4-BEGIN')
				current_block='FW4'
				continue
				;;
			'# <<< FW4-END')
				current_block=''
				continue
				;;
		esac

		case "$current_block" in
			'')
				printf '%s\n' "$line" >> "$output_config_path"
				;;
			SERVICE)
				printf '%s\n' "$line" >> "$output_config_path"
				;;
			FW3)
				if [ "$fw_upper" = 'FW3' ]; then
					printf '%s\n' "$line" >> "$output_config_path"
				fi
				;;
			FW4)
				if [ "$fw_upper" = 'FW4' ]; then
					case "$line" in
						\#[[:space:]]*CONFIG_*=*)
							printf '%s\n' "$(printf '%s' "$line" | sed 's/^#[[:space:]]*//')" >> "$output_config_path"
							;;
						*)
							printf '%s\n' "$line" >> "$output_config_path"
							;;
					esac
				fi
				;;
		esac
	done < "$input_config"
}

show_help() {
	cat <<'EOF'
用法：
  bash Scripts/export_config.sh --device 设备名 --fw fw3|fw4 --output 输出文件 [--overlay 列表] [--config-dir 目录]

示例：
  bash Scripts/export_config.sh \
    --device CMIOT-AX18-NOWIFI \
    --fw fw3 \
    --overlay frps,apk \
    --output /tmp/CMIOT-AX18-NOWIFI-fw3-frps-apk.txt

参数：
  --device      设备名，例如 CMIOT-AX18-NOWIFI、JD-AX1800PRO-WIFI
  --fw          防火墙栈，fw3 或 fw4
  --overlay     可选 overlay 列表，逗号分隔，例如 frps,apk
                同一 OVERLAY_GROUP 内按传入顺序以最后一个为准
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

trap cleanup EXIT

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

if [ -n "$overlay_list" ]; then
	overlay_list=$(normalize_overlay_list "$config_dir" "$overlay_list")
fi

device_config=$(resolve_device_config "$config_dir" "$device" || true)
if [ -z "$device_config" ]; then
	echo "缺少设备配置：$config_dir/${device}.txt 或 $config_dir/${device}-FW3.txt" >&2
	exit 1
fi

resolved_general_configs='GENERAL.txt'
device_config_path="$config_dir/$device_config"
processed_device_config="$device_config_path"
embeds_fw_stack=false
embeds_service_layer=false

if device_config_embeds_fw_stack "$device_config_path"; then
	embeds_fw_stack=true
fi

if device_config_embeds_service_layer "$device_config_path"; then
	embeds_service_layer=true
fi

if [ "$embeds_fw_stack" = true ] || [ "$embeds_service_layer" = true ]; then
	processed_device_config=$(mktemp)
	cleanup_files="$processed_device_config"
	preprocess_device_config "$device_config_path" "$fw" "$processed_device_config"
fi

device_overlay_config="device-overlays/${device}-$(printf '%s' "$fw" | tr '[:lower:]' '[:upper:]').txt"

bash "$MERGE_SCRIPT" \
	"$config_dir" \
	"$resolved_general_configs" \
	"$processed_device_config" \
	"$output_config"

if [ -f "$config_dir/$device_overlay_config" ]; then
	cat "$config_dir/$device_overlay_config" >> "$output_config"
fi

# --fw fw4 时追加 FW4 overlay 覆盖文件
if [ "${fw}" = "fw4" ] || [ "${fw}" = "FW4" ]; then
	fw4_overlay="${device}-FW4.txt"
	if [ -f "$config_dir/$fw4_overlay" ]; then
		cat "$config_dir/$fw4_overlay" >> "$output_config"
	fi
fi

if [ -n "$overlay_list" ]; then
	OLD_IFS=$IFS
	IFS=','
	set -- $overlay_list
	IFS=$OLD_IFS
	for overlay_name in "$@"; do
		overlay_name=$(normalize_overlay_name "$overlay_name")
		[ -n "$overlay_name" ] || continue
		cat "$(resolve_overlay_file "$config_dir" "$overlay_name")" >> "$output_config"
	done
fi

echo "导出完成：$output_config"
