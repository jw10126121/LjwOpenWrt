#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
# 通用的diy配置脚本
# 该脚本在config确认前于openwrt目录下执行
#=================================================

work_dir=$(pwd)
# 运行在openwrt目录下
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【Lin】脚本目录：${current_script_dir}"

if [ $(basename "$(pwd)") != 'openwrt' ]; then
    if [ -d "./openwrt" ]; then
        cd ./openwrt
    else
        echo "【Lin】请在openwrt目录下执行，当前工作目录：$(pwd)" 
        exit 0;
    fi
fi

# 显示帮助信息的函数
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help            显示帮助信息"
    echo "  -i default_ip         设置默认IP，默认192.168.0.1"
    echo "  -n default_name       设置主机名，默认Linjw"
    echo "  -p is_reset_password  是否重置密码，默认true"
    echo "  -t default_theme_name 默认主题，默认不修改"
    echo "  -m package_manager    包管理器类型，默认ipk，可选apk"
}

# 检查是否需要显示帮助信息
[[ "$1" == "-h" || "$1" == "--help" ]] && show_help && exit 0

default_name="Linjw"
default_ip="192.168.0.1"
is_reset_password=true
default_theme_name=''
package_manager='ipk'

# 脚本主体
while getopts "hi:n:p:t:m:" opt; do
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
        m)
            package_manager=$OPTARG
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

# op配置文件
op_config="./.config"
# op.config_generate
CFG_FILE_OP="./package/base-files/files/bin/config_generate"
# lean.config_generate
CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"
# lean.默认配置文件，固件首次刷入后运行
file_default_settings="./package/lean/default-settings/files/zzz-default-settings"

# 是否lean代码
is_code_lean=true
if [ -f "$file_default_settings" ]; then
  is_code_lean=true
else
  is_code_lean=false
fi

if [ "$is_code_lean" == true ]; then
    echo "【Lin】当前源码是否LEAN：${$is_code_lean}"
fi

# 替换时间格式
if find ./package/lean/autocore/files -type f -name 'index.htm' 2>/dev/null | grep -q .; then
    # 修改本地时间格式
    sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' ./package/lean/autocore/files/*/index.htm
    echo "【Lin】修改默认时间格式如：$(date "+%a %Y-%m-%d %H:%M:%S")"
fi

if [ -f "$CFG_FILE_OP" ]; then
    # 修改默认IP地址
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_OP
    # 修改默认主机名
    sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_OP
    echo "【Lin】OP默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
fi

if [ -d "./feeds/luci/modules/luci-mod-system/" ]; then
    #修改immortalwrt.lan关联IP
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
fi

if [ -d "./feeds/luci/modules/luci-mod-status/" ]; then
    #添加编译日期标识
    sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ ${default_name}-$(date "%Y-%m-%d")')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
    echo "【Lin】添加编译日期标识成功：${default_name}-$(date "%Y-%m-%d")"
fi

if [ ! -f "$file_default_settings" ]; then
    #临时修复luci无法保存的问题
    sed -i "s/\[sid\]\.hasOwnProperty/\[sid\]\?\.hasOwnProperty/g" $(find ./feeds/luci/modules/luci-base/ -type f -name "uci.js")  
    echo "【Lin】临时修复luci无法保存的问题"
fi



#LEDE平台调整
if [ -f "$CFG_FILE_LEDE" ]; then
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_LEDE
    sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_LEDE
    echo "【Lin】LEDE默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
fi

# 取消主题默认设置
# find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;


# 设置默认主题
if [ -n "$WRT_THEME" ]; then
    the_exist_theme=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "luci-theme-${WRT_THEME}" -prune)
    if [ -n "$the_exist_theme" ]; then
        # 修改默认主题，（需要使用JS版本主题，否则会进不去后台，提示"Unhandled exception during request dispatching"）
        sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
        
        if ! grep -q "^CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" "${op_config}"; then
            echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> "${op_config}"
        fi
        echo "【Lin】默认主题：${WRT_THEME}，主题目录：${the_exist_theme}"
    else
        echo "【Lin】不存在主题【$WRT_THEME】，使用默认主题"
    fi
else
    echo "【Lin】使用源码默认主题"
fi

# <<<<<<<<<<<< 修复frpc、frps执行问题
[ -f "$file_default_settings" ] && if ! grep -qF '/etc/init.d/frpc' $file_default_settings; then
    temp_file_frp=$(mktemp)
cat <<EOF > "$temp_file_frp"

[ -f /usr/bin/frpc ] && chmod +x /usr/bin/frpc
[ -f /usr/bin/frps ] && chmod +x /usr/bin/frps
[ -f /etc/init.d/frpc ] && chmod +x /etc/init.d/frpc
[ -f /etc/init.d/frps ] && chmod +x /etc/init.d/frps
EOF
    sed -i "/uci commit system/r $temp_file_frp" "${file_default_settings}"
    if grep -qF '/etc/init.d/frpc' $file_default_settings; then
        echo "【Lin】修改frpc、frps执行权限成功！"
    fi
fi
# >>>>>>>>>>>> 修复frpc、frps执行问题

# <<<<<<<<<<<< 修改luci响应时间
[ -f "$file_default_settings" ] && if ! grep -qF "uci set luci.apply.holdoff" $file_default_settings; then
    temp_file_holdoff=$(mktemp)
cat <<EOF > "$temp_file_holdoff"

uci set luci.apply.holdoff=3
uci commit luci
EOF
    sed -i "/uci commit system/r $temp_file_holdoff" "${file_default_settings}"
    rm "$temp_file_holdoff"

    if grep -qF "uci set luci.apply.holdoff" $file_default_settings; then
        echo "【Lin】修改luci提交等待时间成功！"
    fi
fi
# >>>>>>>>>>>> 修改luci响应时间

# <<<<<<<<<<<< 修改dhcp顺序分配ip
[ -f "$file_default_settings" ] && if ! grep -qF 'uci set dhcp.@dnsmasq[0].sequential_ip=' $file_default_settings; then
    temp_file_dhcp=$(mktemp)
    dhcp_ip_start=10
    dhcp_ip_end=254
    dhcp_ip_limit=$((dhcp_ip_end - dhcp_ip_start + 1))
cat <<EOF > "$temp_file_dhcp"

uci set dhcp.@dnsmasq[0].sequential_ip=1
uci set dhcp.lan.start=${dhcp_ip_start}
uci set dhcp.lan.limit=${dhcp_ip_limit}
uci commit dhcp
EOF
    sed -i "/uci commit system/r $temp_file_dhcp" "${file_default_settings}"
    rm "$temp_file_dhcp"

    if grep -qF 'uci set dhcp.@dnsmasq[0].sequential_ip=' $file_default_settings; then
        echo "【Lin】设置DHCP顺序分配${dhcp_ip_start}~${dhcp_ip_end}的IP。"
    fi
fi


if [ -f "$file_default_settings" ]; then
    # 注释openwrt_sqm_scripts_nss
    remove_sqm_scripts_nss="sed -i 's|src/gz openwrt_sqm_scripts_nss|#src/gz openwrt_sqm_scripts_nss|' /etc/opkg/distfeeds.conf"
    sed -i '/openwrt_luci\|helloworld/!b;N;a\\n'"$remove_sqm_scripts_nss" "$file_default_settings"
    if [ $? -eq 0 ]; then
        echo "【Lin】注释feeds中openwrt_sqm_scripts_nss完成"
    else
        echo "【Lin】注释feeds中openwrt_sqm_scripts_nss失败"
    fi

    # 注释openwrt_nss_packages
    remove_nss_packages="sed -i 's|src/gz openwrt_nss_packages|#src/gz openwrt_nss_packages|' /etc/opkg/distfeeds.conf"
    sed -i '/openwrt_luci\|helloworld/!b;N;a\\n'"$remove_nss_packages" "$file_default_settings"
    if [ $? -eq 0 ]; then
        echo "【Lin】注释feeds中openwrt_nss_packages完成"
    else
        echo "【Lin】注释feeds中openwrt_nss_packages失败"
    fi
fi

# theme_argon_dir=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "luci-theme-argon" -prune)
# # 修改argon主题颜色
# if [ -n "$theme_argon_dir" ] && ! grep -q "uci commit argon" $file_default_settings; then
#     temp_file=$(mktemp)
# cat <<EOF > "$temp_file"

# if [ ! -f /etc/config/argon ]; then
#     touch /etc/config/argon
#     uci add argon global
# fi
# uci set argon.@global[0].primary='#31A1A1'
# uci set argon.@global[0].transparency='0.5'
# uci commit argon
# EOF
#     sed -i "/uci commit system/r $temp_file" "${file_default_settings}"
#     rm "$temp_file"
# fi

# if grep -q "uci commit argon" $file_default_settings; then
#     echo "【Lin】修改argon主题色成功"
# fi

# 修复 armv8 设备 xfsprogs 报错
# sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile


# 清空密码
if [[ -f "./package/base-files/files/etc/shadow" && "$is_reset_password" == "true" ]]; then
    sed -i 's/^root:.*:/root:::0:99999:7:::/' "./package/base-files/files/etc/shadow"
    echo "【Lin】密码已清空：./package/base-files/files/etc/shadow"
fi
# 清空密码
if [[ -f "${file_default_settings}" && "$is_reset_password" == "true" ]]; then
    sed -i '/\/etc\/shadow$/{/root::0:0:99999:7:::/d;/root:::0:99999:7:::/d}' "${file_default_settings}"
    echo "【Lin】LEAN配置密码已清空：${file_default_settings}"
fi

# WIFI_NAME=LEDE
# WIFI_PASSWORD=88888888

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
if [ -d "./feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d" ]; then
    sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/ -type f -name "luci-app-alist.json")
fi

if [ -f "$CFG_FILE_LEDE" ]; then
    sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/ -type f -name "luci-app-samba4.json")
fi

# 配置编译信息
if [[ -f "${file_default_settings}" ]]; then
    # 获取版本号
    openwrt_workdir="." #openwrt目录
    config_version=$(grep CONFIG_VERSION_NUMBER "${openwrt_workdir}/.config" | cut -d '=' -f 2 | tr -d '"' | awk '{print $2}')
    include_version=$(grep -oP '^VERSION_NUMBER:=.*,\s*\K[0-9]+\.[0-9]+\.[0-9]+(-*)?' "${openwrt_workdir}/include/version.mk" | tail -n 1 | sed -E 's/([0-9]+\.[0-9]+)\..*/\1/')
    op_version="${config_version:-${include_version}}"
    DISTRIB_REVISION=$(cat "${file_default_settings}" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
    if [[ -n $DISTRIB_REVISION ]]; then
        date_version=$(date +"%y%m%d")
        if [ -n "${op_version}" ]; then
            show_version_text="v${op_version} by Lin on ${date_version}"
            TO_DISTRIB_REVISION="${show_version_text}"
        else
            TO_DISTRIB_REVISION="R${date_version} by Lin"
        fi
        sed -i "/DISTRIB_REVISION=/s/${DISTRIB_REVISION}/${TO_DISTRIB_REVISION}/" "${file_default_settings}"
        echo "【Lin】编译信息修改为：${TO_DISTRIB_REVISION}"
    fi
    # DISTRIB_DESCRIPTION=$(cat "./package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_DESCRIPTION= | awk -F "'" '{print $2}')
    # sed -i "/DISTRIB_DESCRIPTION=/s/${DISTRIB_DESCRIPTION}/Linjw /" ./package/lean/default-settings/files/zzz-default-settings
fi

# 配置NSS
USAGE_FILE="./package/lean/autocore/files/arm/sbin/usage"
if [[ -f "${USAGE_FILE}" ]]; then
    sed -i '/echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"/c\
        if [ -r "/sys/kernel/debug/ecm/ecm_db/connection_count_simple" ]; then\
            connection_count=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count_simple)\
            echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}, ECM: ${connection_count}"\
        else\
            echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"\
        fi' "$USAGE_FILE"
    if [ $? -eq 0 ]; then
        echo "【Lin】配置NSS显示执行完成"
    else
        echo "【Lin】配置NSS显示执行完成"
    fi
fi


# 获取IP地址前3段
WRT_IPPART=$(echo $WRT_IP | cut -d'.' -f1-3)
#修复Openvpnserver无法连接局域网和外网问题
if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
   echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
   echo "【Lin】OpenVPN Server has been fixed and is now accessible on the network!"
fi

# 修复Openvpnserver默认配置的网关地址与无法多终端同时连接问题
if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
    echo "  option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "【Lin】OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
    sed -i "s/192.168.1.1/$WRT_IPPART.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    sed -i "s/192.168.1.0/$WRT_IPPART.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "【Lin】OpenVPN Server has been fixed the default gateway address!"
fi


sed -i "s/^CONFIG_FEED_helloworld=[ym]/CONFIG_FEED_helloworld=n/g" "${op_config}"
sed -i "s/^CONFIG_FEED_sqm_scripts_nss=[ym]/CONFIG_FEED_sqm_scripts_nss=n/g" "${op_config}"
sed -i "s/^CONFIG_FEED_nss_packages=[ym]/CONFIG_FEED_nss_packages=n/g" "${op_config}"

if ! grep -q "^CONFIG_PACKAGE_luci=y" "${op_config}"; then
    echo "CONFIG_PACKAGE_luci=y" >> "${op_config}"
fi

if ! grep -q "^CONFIG_LUCI_LANG_zh_Hans=y" "${op_config}"; then
    echo "CONFIG_LUCI_LANG_zh_Hans=y" >> "${op_config}"
fi


if ! grep -q "^CONFIG_USE_APK=n" "${op_config}"; then
    echo "CONFIG_USE_APK=n" >> "${op_config}"
fi

if [ "${package_manager}" == 'apk' ]; then
    sed -i "s/^CONFIG_USE_APK=[ym]/CONFIG_USE_APK=y/g" "${op_config}"
else
    sed -i "s/^CONFIG_USE_APK=[ym]/CONFIG_USE_APK=n/g" "${op_config}"
    echo "CONFIG_PACKAGE_default-settings-chn=y" >> "${op_config}"
fi


WRT_TARGET='IPQ'

if [ ! -f "$file_default_settings" ]; then
    if [[ $WRT_TARGET == *"IPQ"* ]]; then

        #编译器优化
        echo "CONFIG_TARGET_OPTIONS=y" >> "${op_config}"
        echo "CONFIG_TARGET_OPTIMIZATION=\"-O2 -pipe -march=armv8-a+crypto+crc -mcpu=cortex-a53+crypto+crc -mtune=cortex-a53\"" >> "${op_config}"

        #取消nss相关feed
        echo "CONFIG_FEED_nss_packages=n" >> "${op_config}"
        echo "CONFIG_FEED_sqm_scripts_nss=n" >> "${op_config}"
        #设置NSS版本
        echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> "${op_config}"
        echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> "${op_config}"

    fi
fi

if [ ! -f "$file_default_settings" ]; then
    default_bash_dir='./package/base-files/files/etc/uci-defaults'
    default_bash_script='./package/base-files/files/etc/uci-defaults/99-lin-defaults'
    mkdir -p "$default_bash_dir"
    touch $default_bash_script
    dhcp_ip_start=10
    dhcp_ip_end=254
    dhcp_ip_limit=$((dhcp_ip_end - dhcp_ip_start + 1))
cat <<EOF > $default_bash_script
[ -f /usr/bin/frpc ] && chmod +x /usr/bin/frpc
[ -f /usr/bin/frps ] && chmod +x /usr/bin/frps
[ -f /etc/init.d/frpc ] && chmod +x /etc/init.d/frpc
[ -f /etc/init.d/frps ] && chmod +x /etc/init.d/frps

uci set dhcp.@dnsmasq[0].sequential_ip=1
uci set dhcp.lan.start=${dhcp_ip_start}
uci set dhcp.lan.limit=${dhcp_ip_limit}
uci commit dhcp

uci set luci.apply.holdoff=3
uci commit luci

exit 0
EOF

    chmod +x ${default_bash_script}
    echo "【Lin】配置首次运行脚本成功："
    echo "【Lin】1、修改frpc、frps权限"
    echo "【Lin】2、配置dhcp，起：${dhcp_ip_start}，数：${dhcp_ip_limit}"
    echo "【Lin】3、修改luci响应时间3s"
fi






