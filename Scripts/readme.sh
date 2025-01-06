#!/bin/bash


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

# 脚本主体
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

[ -f "$desc_file" ] && rm -fr "$desc_file"

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
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 集成的插件 ---</summary>" >> $desc_file
	else
		echo "#### --- 集成的插件 --- ####" >> $desc_file
	fi
	
	for item in $pkg_list; do
    	echo "$item" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

pkg_list_package=$(grep "^CONFIG_PACKAGE_luci-app-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//')
if [ -n "$pkg_list_package" ]; then
	echo "" >> $desc_file
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 安装包插件 ---</summary>" >> $desc_file
	else
		echo "#### --- 安装包插件 --- ####" >> $desc_file
	fi
	for item in $pkg_list_package; do
    	echo "$item" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

theme_list=$(grep "^CONFIG_PACKAGE_luci-theme-.*=y$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//')
if [ -n "$theme_list" ]; then
	echo "" >> $desc_file
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 集成的主题 ---</summary>" >> $desc_file
	else
		echo "#### --- 集成的主题 --- ####" >> $desc_file
	fi
	for item in $theme_list; do
        echo "$item" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

theme_list_package=$(grep "^CONFIG_PACKAGE_luci-theme-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//')
if [ -n "$theme_list_package" ]; then
	echo "" >> $desc_file
	if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "<details><summary>--- 安装包主题 ---</summary>" >> $desc_file
	else
		echo "#### --- 安装包主题 --- ####" >> $desc_file
	fi
    for item in $theme_list_package; do
        echo "$item" >> $desc_file
    done
    if [[ $is_release == 'true' || $is_release == true ]]; then
		echo "</details>" >> $desc_file
	fi
fi

echo "" >> $desc_file
