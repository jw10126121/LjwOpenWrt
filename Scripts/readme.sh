#!/bin/bash

# 说明：
# 1. 根据 .config 生成编译说明文件。
# 2. 同时支持普通文本输出和 Release 场景下的 HTML details 折叠输出。

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help            显示帮助信息"
    echo "  -c config_file        配置文件"
    echo "  -o desc_file          输出文件"
    echo "  -s system_desc        固件说明"
    echo "  -a author_note 		  其他说明"
    echo "  -r is_release 	      是否发布"
}

[[ "$1" == "-h" || "$1" == "--help" ]] && show_help && exit 0

# 配置文件
config_file=".config"
# 说明文件
desc_file="readme.txt"
# 编译说明
system_desc=""
# 作者说明
author_note=""
# 是否发布
is_release=false

# 解析传入参数，决定输出位置、附加说明以及是否按 Release 格式渲染。
while getopts "hc:o:s:a:r:" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        c)
            config_file=$OPTARG
            ;;
        o)
            desc_file=$OPTARG
            ;;
        s)
            system_desc=$OPTARG
            ;;
        a)
            author_note=$OPTARG
            ;;
        r)
            is_release=$OPTARG
            if [[ "$OPTARG" =~ ^[1-9][0-9]*$ ]] || [ "$OPTARG" = "true" ]; then
                is_release=true
            else
                is_release=false
            fi
            ;;
        \?)
            echo "无效选项: -$OPTARG" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

trim_value() {
    printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/'
}

parse_pkg_version_value() {
    local raw_value="$1"
    local parsed_value=""

    raw_value="$(trim_value "${raw_value}")"
    parsed_value="$(printf '%s\n' "${raw_value}" | sed -nE 's/^\$\(or[[:space:]]*[^,]+,[[:space:]]*([^)]+)\)$/\1/p')"
    if [ -n "${parsed_value}" ]; then
        raw_value="$(trim_value "${parsed_value}")"
    fi

    case "${raw_value}" in
        ""|*'$('*|*'${'*)
            return 1
            ;;
    esac

    printf '%s' "${raw_value}"
}

find_package_makefile() {
    local search_root="$1"
    local package_name="$2"
    local search_dir=""
    local makefile_path=""

    for search_dir in "${search_root}/package" "${search_root}/feeds" "${search_root}"; do
        [ -d "${search_dir}" ] || continue

        makefile_path="$(find "${search_dir}" \
            \( -name .git -o -name build_dir -o -name staging_dir -o -name tmp -o -name bin \) -prune -o \
            -type f -path "*/${package_name}/Makefile" -print | head -n1)"
        [ -n "${makefile_path}" ] || continue

        printf '%s' "${makefile_path}"
        return 0
    done

    return 1
}

get_package_version() {
    local package_name="$1"
    local makefile_path=""
    local version_line=""

    makefile_path="$(find_package_makefile "${package_search_root}" "${package_name}")"
    [ -n "${makefile_path}" ] || return 1

    version_line="$(sed -nE 's/^[[:space:]]*PKG_VERSION[[:space:]]*[:+?]?=[[:space:]]*(.*)$/\1/p' "${makefile_path}" | head -n1)"
    [ -n "${version_line}" ] || return 1

    parse_pkg_version_value "${version_line}"
}

format_package_line() {
    local package_name="$1"
    local version=""

    version="$(get_package_version "${package_name}")" || {
        printf '%s' "${package_name}"
        return 0
    }

    printf '%s (%s)' "${package_name}" "${version}"
}

package_search_root="$(cd "$(dirname "${config_file}")" 2>/dev/null && pwd -P)"
[ -n "${package_search_root}" ] || package_search_root="$(pwd -P)"

desc_dir="$(dirname "${desc_file}")"
[ -n "${desc_dir}" ] && mkdir -p "${desc_dir}"
[ -f "$desc_file" ] && rm -f "$desc_file"

# 先写固定的编译说明与作者说明，再枚举已编译/可安装的插件与主题。
# 编译说明
if [ -n "$system_desc" ]; then
	echo "" >> $desc_file
	echo "### --- 编译说明 --- ###" >> $desc_file
	echo "$system_desc" >> $desc_file
fi

# 其他说明
if [ -n "$author_note" ]; then
	echo "" >> $desc_file
	echo "### --- 其他说明 --- ###" >> $desc_file
	echo "$author_note" >> $desc_file
fi

pkg_list=$(grep "^CONFIG_PACKAGE_luci-app-.*=y$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//')
if [ -n "$pkg_list" ]; then
	echo "" >> $desc_file
    line_end_text=''
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 集成的插件 ---</summary>" >> $desc_file
        line_end_text='<br>'
	else
		echo "#### --- 集成的插件 --- ####" >> $desc_file
	fi
	
	for item in $pkg_list; do
        package_line="$(format_package_line "${item}")"
    	echo "${package_line}${line_end_text}" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

pkg_list_package=$(grep "^CONFIG_PACKAGE_luci-app-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//')
if [ -n "$pkg_list_package" ]; then
	echo "" >> $desc_file
    line_end_text=''
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 安装包插件 ---</summary>" >> $desc_file
        line_end_text='<br>'
	else
		echo "#### --- 安装包插件 --- ####" >> $desc_file
	fi
	for item in $pkg_list_package; do
        package_line="$(format_package_line "${item}")"
    	echo "${package_line}${line_end_text}" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

theme_list=$(grep "^CONFIG_PACKAGE_luci-theme-.*=y$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//')
if [ -n "$theme_list" ]; then
	echo "" >> $desc_file
    line_end_text=''
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 集成的主题 ---</summary>" >> $desc_file
        line_end_text='<br>'
	else
		echo "#### --- 集成的主题 --- ####" >> $desc_file
	fi
	for item in $theme_list; do
        echo "${item}${line_end_text}" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

theme_list_package=$(grep "^CONFIG_PACKAGE_luci-theme-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//')
if [ -n "$theme_list_package" ]; then
	echo "" >> $desc_file
    line_end_text=''
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 安装包主题 ---</summary>" >> $desc_file
        line_end_text='<br>'
	else
		echo "#### --- 安装包主题 --- ####" >> $desc_file
	fi
    for item in $theme_list_package; do
        echo "${item}${line_end_text}" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

echo "" >> $desc_file
