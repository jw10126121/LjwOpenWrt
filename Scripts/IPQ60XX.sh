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


bash "$(cd $(dirname $0) && pwd)/diy_config.sh" -n "$default_name" -i "$default_ip" -p $is_reset_password -t "$default_theme_name"

# # 配置NSS
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
# 方法二
# NEW_USAGE_FILE="./custom_usage.txt"
# if [ -f "$USAGE_FILE" ]; then
#     if [ -f "$NEW_USAGE_FILE" ]; then
#         cat $NEW_USAGE_FILE > $USAGE_FILE
#         echo "【LinInfo】配置NSS完成"
#     else
#         echo "【LinInfo】不存在新NSS配置：$NEW_USAGE_FILE"
#     fi
# else
#     echo "【LinInfo】NSS不存在：$USAGE_FILE"
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

