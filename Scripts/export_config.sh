#!/bin/bash

# 说明：
# 1. 导出一份可直接分享的合并后配置文件。
# 2. 默认自动解析 GENERAL / SERVICE / FW3 / FW4 基础层。
# 3. 可选叠加 overlay 文件，适合 FRPS 这类小范围差异配置。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_general_configs.sh"
MERGE_SCRIPT="$SCRIPT_DIR/merge_configs.sh"

config_dir='Config'
main_config=''
overlay_config=''
output_config=''
manual_general_configs=''

show_help() {
	cat <<'EOF'
用法：
  bash Scripts/export_config.sh -m 主配置文件 -o 输出文件 [-v 覆盖文件] [-g 基础配置组合] [-c 配置目录]

示例：
  bash Scripts/export_config.sh \
    -m IPQ60XX-NOWIFI-FW3.txt \
    -v IPQ60XX-NOWIFI-FW3-FRPS-override.txt \
    -o /tmp/IPQ60XX-NOWIFI-FW3-FRPS.merged.txt

参数：
  -m  主配置文件，例如 IPQ60XX-NOWIFI-FW3.txt
  -o  输出文件路径
  -v  可选覆盖文件，例如 IPQ60XX-NOWIFI-FW3-FRPS-override.txt
  -g  可选基础配置组合；不传时自动解析
  -c  配置目录，默认 Config
  -h  显示帮助
EOF
}

while getopts "m:o:v:g:c:h" opt; do
	case "$opt" in
		m)
			main_config=$OPTARG
			;;
		o)
			output_config=$OPTARG
			;;
		v)
			overlay_config=$OPTARG
			;;
		g)
			manual_general_configs=$OPTARG
			;;
		c)
			config_dir=$OPTARG
			;;
		h)
			show_help
			exit 0
			;;
		\?)
			show_help >&2
			exit 1
			;;
	esac
done

[ -n "$main_config" ] || {
	echo "Missing main config. Use -m." >&2
	exit 1
}

[ -n "$output_config" ] || {
	echo "Missing output path. Use -o." >&2
	exit 1
}

resolved_general_configs=$(bash "$RESOLVE_SCRIPT" "$manual_general_configs" "$main_config")

if [ -n "$overlay_config" ]; then
	bash "$MERGE_SCRIPT" \
		"$config_dir" \
		"$resolved_general_configs" \
		"$main_config" \
		"$overlay_config" \
		"$output_config"
else
	bash "$MERGE_SCRIPT" \
		"$config_dir" \
		"$resolved_general_configs" \
		"$main_config" \
		"$output_config"
fi

echo "导出完成：$output_config"
