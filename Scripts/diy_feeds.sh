#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
#=================================================
#


openwrt_root="openwrt"
feed_config_name='feeds.conf.default'


# configGit

# cd "$openwrt_root"
sed -i "s/#src-git helloworld/src-git helloworld/g" $feed_config_name

configGit() {

	echo ''
	echo '--------------------------------'
	echo '--配置git config-------------------'
	echo '--------------------------------'
	echo ''	
	git config --global http.postBuffer 524288000
	git config --global http.lowSpeedLimit 0
	git config --global http.lowSpeedTime 999999

}

downloadCode() {
			
	echo ''
	echo '--------------------------------'
	echo '--配置git config-------------------'
	echo '--------------------------------'
	echo ''

	git config --global http.postBuffer 524288000
	git config --global http.lowSpeedLimit 0
	git config --global http.lowSpeedTime 999999

	echo ''
	echo '--------------------------------'
	echo '--更新Lean源码-------------------'
	echo '--------------------------------'
	echo ''

	if [[ ! -d $openwrt_root ]]; then
		# 下载源码
		git clone $lean_code_url -b master $openwrt_root

		if [ $? -ne 0 ]; then
			# 失败
			echo ''
			echo '----------------------------------------------------------------'
			echo '--更新源码失败----------------------------------------------------'
			echo '----------------------------------------------------------------'
			echo ''
			exit 0
		fi

	else

		if [[ $should_update_openwrt -eq 1 ]]; then

			cd $openwrt_root

			# 还原所有内容
			# git checkout . && git clean -xdf

			echo ''
			echo '--------------------------------'
			echo '--当前feeds.conf.default文件:----'
			cat $feed_config_name
			echo '--------------------------------'
			echo ''
			git reset --hard

			git checkout master -f $feed_config_name

			git pull

			if [ $? -ne 0 ]; then
			# 失败
			echo ''
			echo '----------------------------------------------------------------'
			echo '--更新源码失败----------------------------------------------------'
			echo '----------------------------------------------------------------'
			echo ''
			exit 0
			fi
			echo '--------------------------------'
			echo '--强制重置feeds.conf.default文件:-'
			cat $feed_config_name
			echo '--------------------------------'
			cd ..
		fi
	fi
}


configFeeds() {

	if [[ $add_ssr_plus -eq 1 ]]; then
	
		cd $openwrt_root
		# grep -l "src-git lienol https://github.com/Lienol/openwrt-package" $feed_config_name
		# if [ ! $? -eq 0 ]; then 
		# 	echo -e src-git lienol https://github.com/Lienol/openwrt-package >> $feed_config_name
		# fi
		# 删除 src-git helloworld的注释，并重新启用
		#sed -i "/#src-git helloworld https:\/\/github.com\/fw876\/helloworld/d" $feed_config_name
		#echo -e "src-git helloworld https://github.com/fw876/helloworld" >> $feed_config_name
		
	    sed -i "s/#src-git helloworld/src-git helloworld/g" $feed_config_name


		echo '--------------------------------'
		echo '--配置feeds.conf.default文件:----'
		cat $feed_config_name
		echo '--------------------------------'

		cd ..

	fi
}

updateFeeds() {
	echo '--------------------------------'
	echo '--更新Feeds----------------------'
	echo '--------------------------------'
	cd $openwrt_root
	if [[ $should_clean_feeds -eq 1 ]];then
		./scripts/feeds clean
	fi
	./scripts/feeds update -a && ./scripts/feeds install -a
	cd ..
}

	# echo '++++++++++++++++++++++++++++++++'
	# echo '--开始更新源码和Feeds-------------'
	# echo '++++++++++++++++++++++++++++++++'

	# # 一、下载Lean源码
	# downloadCode $lean_code_url 'master'
	# # 二、清理缓存
	# echo '--------------------------------'
	# echo '--清理缓存-----------------------'
	# echo '--------------------------------'
	# rm -rf ./$openwrt_root/tmp
	# # 三、配置并更新Feeds
	# configFeeds
	# updateFeeds

	# echo '++++++++++++++++++++++++++++++++'
	# echo '--结束更新源码和Feeds-------------'
	# echo '++++++++++++++++++++++++++++++++'









