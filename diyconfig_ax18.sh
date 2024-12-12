#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================
# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

WRT_IP=192.168.0.1
WRT_NAME=Linjw
CFG_FILE="./package/base-files/files/bin/config_generate"
WRT_THEME=argon

echo "当前网关IP: $WRT_IP"

# #修改默认IP地址
# sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
# #修改默认主机名
# sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_LEDE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_LEDE

WRT_IPPART=$(echo $WRT_IP | cut -d'.' -f1-3)
#修复Openvpnserver无法连接局域网和外网问题
if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
    echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
    echo "OpenVPN Server has been fixed and is now accessible on the network!"
fi

#修复Openvpnserver默认配置的网关地址与无法多终端同时连接问题
if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
    echo "	option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
    sed -i "s/192.168.1.1/$WRT_IPPART.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    sed -i "s/192.168.1.0/$WRT_IPPART.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "OpenVPN Server has been fixed the default gateway address!"
fi

echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config