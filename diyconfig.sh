#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================
# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
# 修改路由器名称
sed -i 's/OpenWrt/LinjwRouter/g' package/base-files/files/bin/config_generate
# 修改IP
sed -i 's/192.168.1.1/192.168.0.1/g' package/base-files/files/bin/config_generate