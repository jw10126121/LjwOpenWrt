#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
#
#=================================================


package_root='package'

# 修改路由器名称
sed -i 's/OpenWrt/LinjwRouter/g' $package_root/base-files/files/bin/config_generate
# 修改IP
sed -i 's/192.168.1.1/192.168.1.1/g' $package_root/base-files/files/bin/config_generate
#sed -i 's/192.168.$(/192.168.$(/g' $package_root/base-files/files/bin/config_generate
# 修改wifi信息
sed -i 's/set wireless.default_radio${devidx}.ssid=OpenWrt/set wireless.default_radio${devidx}.ssid=ljwAP/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
sed -i 's/set wireless.default_radio${devidx}.encryption=none/set wireless.default_radio${devidx}.encryption=psk2 \r\t\t\t			set wireless.default_radio${devidx}.key=12356789/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改登录密码
sed -i 's/root::0:0:99999:7:::/root:$1$c7pbpCMC$5qcpVIj8ptyvUQpAJ6m74\/:18369:0:99999:7:::/g' $package_root/base-files/files/etc/shadow
