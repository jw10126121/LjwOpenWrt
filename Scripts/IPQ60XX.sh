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


bash "$(cd $(dirname $0) && pwd)/diy_config.sh" -n "$default_name" -i "$default_ip" -p $is_reset_password -t "$default_theme_name"

# # 配置NSS
# USAGE_FILE="./package/lean/autocore/files/arm/sbin/usage"
# sed -i '/echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"/c\
#     if [ -r "/sys/kernel/debug/ecm/ecm_db/connection_count_simple" ]; then\
#         connection_count=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count_simple)\
#         echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}, ECM: ${connection_count}"\
#     else\
#         echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"\
#     fi' "$USAGE_FILE"
# if [ $? -eq 0 ]; then
#     echo "【Lin】配置NSS显示执行完成"
# else
#     echo "【Lin】配置NSS显示执行完成"
# fi
# 方法二
# NEW_USAGE_FILE="./custom_usage.txt"
# if [ -f "$USAGE_FILE" ]; then
#     if [ -f "$NEW_USAGE_FILE" ]; then
#         cat $NEW_USAGE_FILE > $USAGE_FILE
#         echo "【Lin】配置NSS完成"
#     else
#         echo "【Lin】不存在新NSS配置：$NEW_USAGE_FILE"
#     fi
# else
#     echo "【Lin】NSS不存在：$USAGE_FILE"
# fi

# #获取IP地址前3段
# WRT_IPPART=$(echo $WRT_IP | cut -d'.' -f1-3)
# #修复Openvpnserver无法连接局域网和外网问题
# if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
#    echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
#    echo "【Lin】OpenVPN Server has been fixed and is now accessible on the network!"
# fi

# #修复Openvpnserver默认配置的网关地址与无法多终端同时连接问题
# if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
#     echo "  option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
#     echo "【Lin】OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
#     sed -i "s/192.168.1.1/$WRT_IPPART.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
#     sed -i "s/192.168.1.0/$WRT_IPPART.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
#     echo "【Lin】OpenVPN Server has been fixed the default gateway address!"
# fi


# version_workdir="."
# # 修复lang_node编译问题
# config_version=$(grep CONFIG_VERSION_NUMBER "${version_workdir}/.config" | cut -d '=' -f 2 | tr -d '"' | awk '{print $2}')
# include_version=$(grep -oP '^VERSION_NUMBER:=.*,\s*\K[0-9]+\.[0-9]+\.[0-9]+(-*)?' "${version_workdir}/include/version.mk" | tail -n 1 | sed -E 's/([0-9]+\.[0-9]+)\..*/\1/')
# package_version=$(grep 'openwrt-' "${version_workdir}/feeds.conf.default" | grep -oP 'openwrt-\K[^;]*')
# op_version="${config_version:-${include_version:-${package_version}}}"
# echo "【Lin】openwrt版本号：${op_version}；config_version：${config_version:-无}；include_version：${include_version:-无}；package_version：${package_version:-无}"
# if [ -n "$op_version" ]; then  
#     path_node_makefile="${version_workdir}/feeds/packages/lang/node"
#     path_node_dir_bak="${version_workdir}/feeds/packages/lang/bak_node"
#     [ -d "$path_node_dir_bak" ] && rm -fr "$path_node_dir_bak"
#     [ -d "$path_node_makefile" ] && mv -f "$path_node_makefile" "$path_node_dir_bak" && echo "【Lin】备份lang_node：${path_node_makefile} -> ${path_node_dir_bak}"

#     git clone -b "packages-$op_version" https://github.com/sbwml/feeds_packages_lang_node-prebuilt "$path_node_makefile"

#     if [ -d "$path_node_makefile" ]; then
#         echo "【Lin】替换lang_node for openwrt_${op_version}成功：${path_node_makefile}"
#         [ -d "$path_node_dir_bak" ] && rm -fr "$path_node_dir_bak"
#     else
#         mv -f "$path_node_dir_bak" "$path_node_makefile"
#         echo "【Lin】替换lang_node for openwrt_${op_version}失败，还原lang_node"
#     fi
# else
#     echo "【Lin】openwrt版本号未知"
# fi





