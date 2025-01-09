#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
# 通用的diy配置脚本
# 需要在确认配置后再运行
#=================================================




# 显示帮助信息的函数
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help            显示帮助信息"
    echo "  -i default_ip         设置默认IP，默认192.168.0.1"
    echo "  -n default_name       设置主机名，默认Linjw"
    echo "  -p is_reset_password  是否重置密码，默认true"
    echo "  -t default_theme_name 默认主题，默认不修改"
}

# 检查是否需要显示帮助信息
[[ "$1" == "-h" || "$1" == "--help" ]] && show_help && exit 0

default_name="Linjw"
default_ip="192.168.0.1"
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
            # echo "input.default_name: $default_name"
            ;;
        i)
            default_ip=$OPTARG
            # echo "input.default_ip: $default_ip"
            ;;
        p)
            is_reset_password=$OPTARG
            # echo "input.is_reset_password: $is_reset_password"
            if [[ "$OPTARG" =~ ^[1-9][0-9]*$ ]] || [ "$OPTARG" = "true" ]; then
                is_reset_password=true
            else
                is_reset_password=false
            fi
            ;;
        t)
            default_theme_name=$OPTARG
            # echo "input.default_theme_name: $default_theme_name"
            ;;
        \?)
            echo "无效选项: -$OPTARG" >&2
            show_help >&2
            exit 1
            ;;
    esac
done


WRT_IP=$default_ip
WRT_NAME=$default_name
WRT_THEME=$default_theme_name

CFG_FILE="./package/base-files/files/bin/config_generate"
CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"
file_default_settings="./package/lean/default-settings/files/zzz-default-settings"

# 替换时间格式
if find ./package/lean/autocore/files -type f -name 'index.htm' 2>/dev/null | grep -q .; then
    # 修改本地时间格式
    sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' ./package/lean/autocore/files/*/index.htm
    echo "【LinInfo】修改默认时间格式如：$(date "+%a %Y-%m-%d %H:%M:%S")"
fi

if [ -f "$CFG_FILE" ]; then
    # 修改默认IP地址
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
    echo "【LinInfo】默认IP: $WRT_IP"
    # 修改默认主机名
    sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
    echo "【LinInfo】默认主机名: 主机名：$WRT_NAME"
fi

#LEDE平台调整
if [ -f "$CFG_FILE_LEDE" ]; then
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_LEDE
    sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_LEDE
    echo "【LinInfo】LEDE默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
fi

# 取消主题默认设置
# find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;
# 设置默认主题
if [ -n "$default_theme_name" ]; then
    the_exist_theme=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "*${default_theme_name}" -prune)
    echo "【LinInfo】搜索到主题：$the_exist_theme"
    if [ -n "$the_exist_theme" ]; then
        # 修改默认主题，（需要使用JS版本主题，否则会进不去后台，提示"Unhandled exception during request dispatching"）
        sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
        # 旧版修改主题方法，现在应该是找不到了
        # sed -i "s/luci-theme-bootstrap/luci-theme-design/g" ./feeds/luci/collections/luci/Makefile
        echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
        if ! grep -q "^CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" "./.config"; then
            echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
        fi
        echo "【LinInfo】默认主题：$WRT_THEME"
    else
        echo "【LinInfo】不存在主题【$WRT_THEME】，使用默认主题"
    fi
else
    echo "【LinInfo】使用源码默认主题"
fi

# 修改argon主题颜色
# if ! grep -q "uci commit argon" $file_default_settings; then
#     # 创建一个临时文件来保存要插入的内容
#     temp_file=$(mktemp)
#     # 将要插入的内容写入临时文件
# cat <<EOF > "$temp_file"

# if [ ! -f /etc/config/argon ]; then
#     touch /etc/config/argon
#     uci add argon global
# fi
# uci set argon.@global[0].primary='#31A1A1'
# uci set argon.@global[0].transparency='0.3'
# uci commit argon
# EOF
#     # 使用sed命令在uci commit system之后插入内容
#     sed -i "/uci commit system/r $temp_file" "${file_default_settings}"
#     rm "$temp_file"
# fi

# 修复 armv8 设备 xfsprogs 报错
# sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile


# 清空密码
if [[ -f "./package/base-files/files/etc/shadow" && "$is_reset_password" == "true" ]]; then
    sed -i 's/^root:.*:/root:::0:99999:7:::/' "./package/base-files/files/etc/shadow"
    echo "【LinInfo】密码已清空：./package/base-files/files/etc/shadow"
fi
# 清空密码
if [[ -f "${file_default_settings}" && "$is_reset_password" == "true" ]]; then
    sed -i '/\/etc\/shadow$/{/root::0:0:99999:7:::/d;/root:::0:99999:7:::/d}' "${file_default_settings}"
    echo "【LinInfo】LEAN配置密码已清空：${file_default_settings}"
fi

WIFI_NAME=LEDE
WIFI_PASSWORD=88888888

# # 修改wifi国家
# sed -i 's/set wireless.radio\${devidx}.type=mac80211/set wireless.radio\${devidx}.type=mac80211 \n\t\t\t set wireless.radio\${devidx}.country=\"CN\"/g' ./kernel/mac80211/files/lib/wifi/mac80211.sh
# # 修改wifi名
# sed -i "s/set wireless.default_radio\\${devidx}.ssid=OpenWrt/set wireless.default_radio\\${devidx}.ssid=${WIFI_NAME}/g" ./kernel/mac80211/files/lib/wifi/mac80211.sh
# # 修改wifi密码
# sed -i "s/set wireless.default_radio\\${devidx}.encryption=none/set wireless.default_radio\\${devidx}.encryption=psk-mixed \\n\\t\\t\\t set wireless.default_radio\\${devidx}.key=${WIFI_PASSWORD}/g" ./kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改2.4G wifi信道
# sed -i 's/channel=\"11\"/channel=\"1\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改5G wifi信道
# sed -i 's/channel=\"36\"/channel=\"153\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh

# 调整位置
sed -i 's/services/system/g' $(find ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/ -type f -name "luci-app-ttyd.json")
sed -i '3 a\\t\t"order": 10,' $(find ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/ -type f -name "luci-app-ttyd.json")
sed -i 's/services/network/g' $(find ./feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/ -type f -name "luci-app-upnp.json")
sed -i 's/services/network/g' $(find ./feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/ -type f -name "luci-app-nlbwmon.json")
sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-hd-idle/root/usr/share/luci/menu.d/ -type f -name "luci-app-hd-idle.json")
sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/ -type f -name "luci-app-alist.json")

if [ -f "$CFG_FILE_LEDE" ]; then
    sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/ -type f -name "luci-app-samba4.json")
fi

# 配置编译信息
if [[ -f "${file_default_settings}" ]]; then
    # 配置编译日期
    date_version=$(date +"%y.%m.%d")
    DISTRIB_REVISION=$(cat "${file_default_settings}" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
    if [[ -n $DISTRIB_REVISION ]]; then
        TO_DISTRIB_REVISION="R${date_version} by Linjw"
        sed -i "/DISTRIB_REVISION=/s/${DISTRIB_REVISION}/${TO_DISTRIB_REVISION}/" "${file_default_settings}"
        echo "【LinInfo】编译信息修改为：${TO_DISTRIB_REVISION}"
    fi
    # DISTRIB_DESCRIPTION=$(cat "./package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_DESCRIPTION= | awk -F "'" '{print $2}')
    # sed -i "/DISTRIB_DESCRIPTION=/s/${DISTRIB_DESCRIPTION}/Linjw /" ./package/lean/default-settings/files/zzz-default-settings
fi

# 配置NSS
USAGE_FILE="./package/lean/autocore/files/arm/sbin/usage"
sed -i '/echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"/c\
    if [ -r "/sys/kernel/debug/ecm/ecm_db/connection_count_simple" ]; then\
        connection_count=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count_simple)\
        echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}, ECM: ${connection_count}"\
    else\
        echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"\
    fi' "$USAGE_FILE"
if [ $? -eq 0 ]; then
    echo "【LinInfo】配置NSS显示执行完成"
else
    echo "【LinInfo】配置NSS显示执行完成"
fi

#获取IP地址前3段
WRT_IPPART=$(echo $WRT_IP | cut -d'.' -f1-3)
#修复Openvpnserver无法连接局域网和外网问题
if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
   echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
   echo "【LinInfo】OpenVPN Server has been fixed and is now accessible on the network!"
fi

#修复Openvpnserver默认配置的网关地址与无法多终端同时连接问题
if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
    echo "  option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "【LinInfo】OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
    sed -i "s/192.168.1.1/$WRT_IPPART.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    sed -i "s/192.168.1.0/$WRT_IPPART.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "【LinInfo】OpenVPN Server has been fixed the default gateway address!"
fi


sed -i "s/^CONFIG_FEED_helloworld=y/CONFIG_FEED_helloworld=n/g" ./.config

sed -i "s/^CONFIG_FEED_sqm_scripts_nss=y/CONFIG_FEED_sqm_scripts_nss=n/g" ./.config

sed -i "s/^CONFIG_FEED_nss_packages=y/CONFIG_FEED_nss_packages=n/g" ./.config


if ! grep -q "^CONFIG_PACKAGE_luci=y" "./.config"; then
    echo "CONFIG_PACKAGE_luci=y" >> ./.config
fi

if ! grep -q "^CONFIG_LUCI_LANG_zh_Hans=y" "./.config"; then
    echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
fi

