#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
# 通用的diy配置脚本
# 该脚本在config确认后于openwrt目录下执行
#=================================================

# 运行在openwrt目录下
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【LinInfo】脚本目录：${current_script_dir}"

# 获取CPU架构
cputype=$(grep -m 1 "^CONFIG_TARGET_ARCH_PACKAGES=" ./.config | awk -F'=' '{print $2}' | tr -d '"')
cputype_simple=''
# 定义支持的 ARM64 架构处理器型号
arm64_processors=("cortex-a53" "cortex-a57" "cortex-a73" "cortex-a77")
# 判断是否包含这些处理器型号
for processor in "${arm64_processors[@]}"; do
    [[ "$cputype" == *"$processor"* ]] && cputype_simple='arm64' && break
done

if [ -z "${cputype_simple}" ]; then
    # 定义 x86 架构相关的关键词
    x86_keywords=("x86" "amd64")
    # 判断是否包含 x86 架构关键词
    for keyword in "${x86_keywords[@]}"; do
        [[ "$cputype" == *"$keyword"* ]] && cputype_simple='amd64' && break
    done   
fi

echo "【LinInfo】设备架构：${cputype_simple:-'未知架构'} ${cputype}"
# 从配置文件中，获取值
choose_type_openclash=$(grep -m 1 "^CONFIG_PACKAGE_luci-app-openclash=" ./.config | awk -F'=' '{print $2}' | tr -d '"')
openclash_DIR=$(find ./package/*/ -maxdepth 3 -type d -iname "luci-app-openclash" -prune)
# 预置OpenClash内核和数据
if [ -n "${choose_type_openclash}" ] && [ -d "${openclash_DIR}" ] && [ -n "${cputype_simple}" ]; then
    echo "【LinInfo】准备下载openclash资源，架构：${cputype_simple}"
    
    # CORE_TYPE=$(echo $WRT_TARGET | grep -Eiq "64|86" && echo "amd64" || echo "arm64")
    CORE_TYPE="${cputype_simple}"

    CORE_VER="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/core_version"
    CORE_TUN_VER=$(curl -sL $CORE_VER | sed -n "2{s/\r$//;p;q}")

    CORE_DEV="https://github.com/vernesong/OpenClash/raw/core/dev/dev/clash-linux-$CORE_TYPE.tar.gz"
    CORE_MATE="https://github.com/vernesong/OpenClash/raw/core/dev/meta/clash-linux-$CORE_TYPE.tar.gz"
    CORE_TUN="https://github.com/vernesong/OpenClash/raw/core/dev/premium/clash-linux-$CORE_TYPE-$CORE_TUN_VER.gz"

    GEO_MMDB="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"
    GEO_SITE="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geosite.dat"
    GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"

    cd "${openclash_DIR}/root/etc/openclash/"

    curl -sL -o Country.mmdb $GEO_MMDB && echo "Country.mmdb done!"
    curl -sL -o GeoSite.dat $GEO_SITE && echo "GeoSite.dat done!"
    curl -sL -o GeoIP.dat $GEO_IP && echo "GeoIP.dat done!"

    mkdir ./core/ && cd ./core/

    curl -sL -o meta.tar.gz $CORE_MATE && tar -zxf meta.tar.gz && mv -f clash clash_meta && echo "meta done!"
    curl -sL -o tun.gz $CORE_TUN && gzip -d tun.gz && mv -f tun clash_tun && echo "tun done!"
    curl -sL -o dev.tar.gz $CORE_DEV && tar -zxf dev.tar.gz && echo "dev done!"

    chmod +x ./* && rm -rf ./*.gz

    cd "${current_script_dir}"

    echo "【LinInfo】openclash date has been updated!"
fi












