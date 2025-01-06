#!/bin/bash



config_file=$1

desc_file=$2

compile_desc=$3

is_release=$4 || 'false'

rm -fr $desc_file

# 编译说明
if [ -n "$compile_desc" ]; then
	echo "" >> $desc_file
	echo "### --- 编译说明 --- ###" >> $desc_file
	echo "$compile_desc" >> $desc_file
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
