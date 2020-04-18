#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
#=================================================
#

openwrt_root='openwrt'
lean_code_url='https://github.com/coolsnowwolf/lede'
feed_config_name='feeds.conf.default'

downloadCode() {
	echo '--------------------------------'
	echo '--更新Lean源码-------------------'
	echo '--------------------------------'
	if [[ ! -d $openwrt_root ]]; then
		git clone --depth 1 $1 -b $2 $openwrt_root
	else
		cd $openwrt_root
		echo '--------------------------------'
		echo '--当前feeds.conf.default文件:----'
		cat $feed_config_name
		echo '--------------------------------'
		
		git reset --hard

		git checkout master -f $feed_config_name

		git pull
		echo '--------------------------------'
		echo '--强制重置feeds.conf.default文件:-'
		cat $feed_config_name
		echo '--------------------------------'
		
		cd ..
	fi
}


configFeeds() {
	
	cd $openwrt_root
	grep -l "src-git lienol https://github.com/Lienol/openwrt-package" $feed_config_name
	if [ ! $? -eq 0 ]; then 
		echo -e src-git lienol https://github.com/Lienol/openwrt-package >> $feed_config_name
	fi
	# 删除 src-git helloworld的注释，并重新启用
	sed -i "/#src-git helloworld https:\/\/github.com\/fw876\/helloworld/d" $feed_config_name
	echo -e "src-git helloworld https://github.com/fw876/helloworld" >> $feed_config_name

	echo '--------------------------------'
	echo '--配置feeds.conf.default文件:----'
	cat $feed_config_name
	echo '--------------------------------'

	cd ..
}

updateFeeds() {
	echo '--------------------------------'
	echo '--更新Feeds----------------------'
	echo '--------------------------------'
	cd $openwrt_root
	./scripts/feeds update -a && ./scripts/feeds install -a
	cd ..
}

	echo '++++++++++++++++++++++++++++++++'
	echo '--开始更新源码和Feeds-------------'
	echo '++++++++++++++++++++++++++++++++'

	# 一、下载Lean源码
	downloadCode $lean_code_url 'master'
	# 二、清理缓存
	echo '--------------------------------'
	echo '--清理缓存-----------------------'
	echo '--------------------------------'
	rm -rf ./$openwrt_root/tmp
	# 三、配置并更新Feeds
	configFeeds
	updateFeeds

	echo '++++++++++++++++++++++++++++++++'
	echo '--结束更新源码和Feeds-------------'
	echo '++++++++++++++++++++++++++++++++'









