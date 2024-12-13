#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
#=================================================

WRT_IP=192.168.0.1
WRT_NAME=Linjw
CFG_FILE="./package/base-files/files/bin/config_generate"
CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"
WRT_THEME=argon

echo "当前网关IP: $WRT_IP"

# 修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
# 修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# 修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

echo "【LinInfo】默认：IP: $WRT_IP，主机名：$WRT_NAME，主题：$WRT_THEME"

#LEDE平台调整
if [ -f "$CFG_FILE_LEDE" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_LEDE
	sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_LEDE
    echo "【LinInfo】LEDE：IP: $WRT_IP，主机名：$WRT_NAME，主题：$WRT_THEME"
fi

# 清空密码
# sed -i 's/^root:.*:/root:::0:99999:7:::/' "./package/base-files/files/etc/shadow"

# 配置NSS
USAGE_FILE="./package/lean/autocore/files/arm/sbin/usage"
if [ -f "$USAGE_FILE" ]; then
    cat $GITHUB_WORKSPACE/Scripts/patch/usage > $USAGE_FILE
    echo "【LinInfo】配置NSS："
    echo "$(cat $GITHUB_WORKSPACE/Scripts/patch/usage)"
fi

#调整位置
sed -i 's/services/system/g' $(find ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/ -type f -name "luci-app-ttyd.json")
sed -i '3 a\\t\t"order": 10,' $(find ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/ -type f -name "luci-app-ttyd.json")
sed -i 's/services/network/g' $(find ./feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/ -type f -name "luci-app-upnp.json")
# sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/ -type f -name "luci-app-alist.json")
# if [ -f "$CFG_FILE_LEDE" ]; then
# 	sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/ -type f -name "luci-app-samba4.json")
# fi

#获取IP地址前3段
WRT_IPPART=$(echo $WRT_IP | cut -d'.' -f1-3)
#修复Openvpnserver无法连接局域网和外网问题
if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
    echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
    echo "OpenVPN Server has been fixed and is now accessible on the network!"
fi

#修复Openvpnserver默认配置的网关地址与无法多终端同时连接问题
if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
    echo "  option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
    sed -i "s/192.168.1.1/$WRT_IPPART.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    sed -i "s/192.168.1.0/$WRT_IPPART.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "OpenVPN Server has been fixed the default gateway address!"
fi

echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config

