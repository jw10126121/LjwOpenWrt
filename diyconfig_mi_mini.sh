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
#sed -i 's/192.168.\$(/192.168.\$(/g' $package_root/base-files/files/bin/config_generate

# 修改wifi信息

# 修改wifi国家
sed -i 's/set wireless.radio\${devidx}.type=mac80211/set wireless.radio\${devidx}.type=mac80211 \n\t\t\t set wireless.radio\${devidx}.country=\"CN\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改2.4G wifi信道
sed -i 's/channel=\"11\"/channel=\"1\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改5G wifi信道
sed -i 's/channel=\"36\"/channel=\"153\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改wifi名
sed -i 's/set wireless.default_radio\${devidx}.ssid=OpenWrt/set wireless.default_radio\${devidx}.ssid=ljwAP/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改wifi密码
sed -i 's/set wireless.default_radio\${devidx}.encryption=none/set wireless.default_radio\${devidx}.encryption=psk-mixed \n\t\t\t set wireless.default_radio\${devidx}.key=12356789/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh

# 修改登录密码
sed -i 's/root::0:0:99999:7:::/root:$1$c7pbpCMC$5qcpVIj8ptyvUQpAJ6m74\/:18369:0:99999:7:::/g' $package_root/base-files/files/etc/shadow

#########
#
#	某些设置，也可以通过$package_root/package/lean/default-settings/files/zzz-default-settings进行修改
#	如：修改登录密码
#	sed -i 's/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/root:$1$c7pbpCMC$5qcpVIj8ptyvUQpAJ6m74\/:18369:0:99999:7:::/g' $package_root/package/lean/default-settings/files/zzz-default-settings
