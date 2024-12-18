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

echo "" >> $desc_file
echo "### --- --- --- 安装包插件 --- --- --- ###" >> $desc_file
grep "^CONFIG_PACKAGE_luci-app-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//' >> $desc_file

echo "" >> $desc_file
echo "### --- --- --- 包含的主题 --- --- --- ###" >> $desc_file
grep "^CONFIG_PACKAGE_luci-theme-.*=y$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//' >> $desc_file


echo "" >> $desc_file
echo "### --- --- --- 安装包主题 --- --- --- ###" >> $desc_file
grep "^CONFIG_PACKAGE_luci-theme-.*=m$" $config_file | sed 's/^CONFIG_PACKAGE_//' | sed 's/=m$//' >> $desc_file


echo "" >> $desc_file