#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
#=================================================

# 显示帮助信息的函数
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help            显示帮助信息"
    echo "  -i default_ip         设置默认IP，默认192.168.1.1"
    echo "  -n default_name       设置主机名，默认Linjw"
    echo "  -p is_reset_password  是否重置密码，默认true"
    echo "  -t default_theme_name 默认主题，默认不修改"
}

# 检查是否需要显示帮助信息
[[ "$1" == "-h" || "$1" == "--help" ]] && show_help && exit 0

default_name="Linjw"
default_ip="192.168.1.1"
is_reset_password=true
default_theme_name=''

# 脚本主体
while getopts "hi:n:p:t:" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        n)
            default_name=$OPTARG
            ;;
        i)
            default_ip=$OPTARG
            ;;
        p)
            is_reset_password=$OPTARG
            if [[ "$OPTARG" =~ ^[1-9][0-9]*$ ]] || [ "$OPTARG" = "true" ]; then
                is_reset_password=true
            else
                is_reset_password=false
            fi
            ;;
        t)
            default_theme_name=$OPTARG
            ;;
        \?)
            echo "无效选项: -$OPTARG" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

echo "default_name: $default_name"
echo "default_ip: $default_ip"
echo "is_reset_password: $is_reset_password"
echo "default_theme_name: $default_theme_name"

WRT_IP=$default_ip
WRT_NAME=$default_name
WRT_THEME=$default_theme_name

CFG_FILE="./package/base-files/files/bin/config_generate"
CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"

echo "当前网关IP: $WRT_IP"

if [ -f "$CFG_FILE" ]; then
    # 修改默认IP地址
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
    echo "【LinInfo】默认IP: $WRT_IP"
    # 修改默认主机名
    sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
    echo "【LinInfo】默认主机名: 主机名：$WRT_NAME"
fi


if [ -n "$default_theme_name" ]; then
    the_exist_theme=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "*${default_theme_name}" -prune)
    if [ -n "$the_exist_theme" ]; then
        # 修改默认主题
        sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
        echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
        echo "【LinInfo】默认主题名：$WRT_THEME"
    else
        echo "【LinInfo】不存在主题【$WRT_THEME】，使用默认主题"
    fi
fi


#LEDE平台调整
if [ -f "$CFG_FILE_LEDE" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_LEDE
	sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_LEDE
    echo "【LinInfo】LEDE默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
fi

# 清空密码
if [[ -f "./package/base-files/files/etc/shadow" && "$is_reset_password" == "true" ]]; then
    sed -i 's/^root:.*:/root:::0:99999:7:::/' "./package/base-files/files/etc/shadow"
    echo "【LinInfo】密码已清空"
fi

# 配置NSS
USAGE_FILE="./package/lean/autocore/files/arm/sbin/usage"
if [ -f "$USAGE_FILE" ]; then
    NEW_USAGE_FILE="./custom_usage.txt"
    if [ -f "$NEW_USAGE_FILE" ]; then
        cat $NEW_USAGE_FILE > $USAGE_FILE
        echo "【LinInfo】配置NSS完成"
    else
        echo "【LinInfo】不存在新NSS配置：$NEW_USAGE_FILE"
    fi
else
    echo "【LinInfo】NSS不存在：$USAGE_FILE"
fi

# 调整位置
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

