#!/bin/bash



config_file=$1

desc_file=$2

compile_desc=$3

rm -fr $desc_file

# 编译说明
if [ -n "$compile_desc" ]; then
	echo "" >> $desc_file
	echo "### --- --- --- 编译说明 --- --- --- ###" >> $desc_file
	echo "$compile_desc" >> $desc_file
fi

echo "" >> $desc_file
echo "### --- --- --- 集成的插件 --- --- --- ###" >> $desc_file
grep "^CONFIG_PACKAGE_luci-app-.*=y$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//' >> $desc_file

pkg_list_package=$(grep "^CONFIG_PACKAGE_luci-app-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//')
if [ -n "$pkg_list_package" ]; then
	echo "" >> $desc_file
	echo "### --- --- --- 安装包插件 --- --- --- ###" >> $desc_file
	for item in $pkg_list_package; do
    	echo "$item" >> $desc_file
    done
fi

theme_list=$(grep "^CONFIG_PACKAGE_luci-theme-.*=y$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//')
if [ -n "$theme_list" ]; then
	echo "" >> $desc_file
	echo "### --- --- --- 集成的主题 --- --- --- ###" >> $desc_file
	for item in $theme_list; do
        echo "$item" >> $desc_file
    done
fi

theme_list_package=$(grep "^CONFIG_PACKAGE_luci-theme-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//')
if [ -n "$theme_list_package" ]; then
	echo "" >> $desc_file
	echo "### --- --- --- 安装包主题 --- --- --- ###" >> $desc_file
    for item in $theme_list_package; do
        echo "$item" >> $desc_file
    done
fi


echo "" >> $desc_file
