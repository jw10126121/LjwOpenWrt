#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
# 通用的diy配置脚本
# 该脚本在config确认后于openwrt目录下执行
# 主要职责：根据最终 .config 补充架构相关资源，例如 HomeProxy 规则集。
#=================================================

# 运行在openwrt目录下
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【Lin】脚本目录：${current_script_dir}"
current_dir=$(pwd)
openwrt_workdir="${current_dir}"

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

echo "【Lin】设备架构：${cputype_simple:-'未知架构'} ${cputype}"

get_config_value() {
    local key="$1"
    grep -m 1 "^${key}=" ./.config | awk -F'=' '{print $2}' | tr -d '"'
}

trim_passwall_variants_after_defconfig() {
    local choose_type_passwall
    local passwall_makefile

    choose_type_passwall=$(get_config_value "CONFIG_PACKAGE_luci-app-passwall")
    if [ -n "${choose_type_passwall}" ] && [ "${choose_type_passwall}" != "n" ]; then
        echo "【Lin】已启用 luci-app-passwall，跳过默认变体裁剪"
        return 0
    fi

    passwall_makefile=$(find ./package ./feeds/luci ./feeds/packages -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile" -print -quit 2>/dev/null)
    if [ -z "${passwall_makefile}" ] || [ ! -f "${passwall_makefile}" ]; then
        echo "【Lin】未找到 luci-app-passwall/Makefile，跳过默认变体裁剪"
        return 0
    fi

    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Haproxy/,/x86_64/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Client/,/x86_64/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Server/,/default n/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Simple_Obfs/,/default y/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_SingBox/,/x86_64/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_V2ray_Geo/,/default [ny]/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_V2ray_Plugin/,/x86_64/d' "${passwall_makefile}"
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Xray/,/x86_64/d' "${passwall_makefile}"
    sed -i '/INCLUDE_Haproxy/d; /INCLUDE_Shadowsocks_Rust_Client/d; /INCLUDE_Shadowsocks_Rust_Server/d; /INCLUDE_Simple_Obfs/d; /INCLUDE_SingBox/d; /INCLUDE_V2ray_Geo/d; /INCLUDE_V2ray_Plugin/d; /INCLUDE_Xray/d' "${passwall_makefile}"
    sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' "${passwall_makefile}"

    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy=/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Client=/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Rust_Server=/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs=/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_SingBox=/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geo/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin=/d' ./.config
    sed -i '/^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=/d' ./.config

    make defconfig >/dev/null 2>&1
    echo "【Lin】passwall 默认变体已在 defconfig 后裁剪"
    return 0
}

trim_passwall_variants_after_defconfig

cd "${openwrt_workdir}"
# HomeProxy 规则依赖外部 surge-rules 仓库，这里在编译前直接预置到插件资源目录。
choose_type_homeproxy=$(grep -m 1 "^CONFIG_PACKAGE_luci-app-homeproxy=" ./.config | awk -F'=' '{print $2}' | tr -d '"')
# homeproxy_DIR=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "luci-app-homeproxy" -prune)
app_homeproxy_dir=$(find ./package ./feeds/luci ./feeds/packages -maxdepth 3 -type d -iname "luci-app-homeproxy" -print -quit 2>/dev/null)
if [ -n "${choose_type_homeproxy}" ] && [ "${choose_type_homeproxy}" != "n" ] && [ -d "${app_homeproxy_dir}" ]; then

    homeproxy_DIR=$(readlink -f "${app_homeproxy_dir}")

    # 预置HomeProxy数据
    if [ -d "${homeproxy_DIR}" ]; then
        HP_RULES="${homeproxy_DIR}/root/etc/homeproxy/my_surge"
        HP_PATCH="${homeproxy_DIR}/root/etc/homeproxy"

        chmod +x $HP_PATCH/scripts/*
        rm -rf $HP_PATCH/resources/*
        [ -d "${HP_RULES}" ] && rm -fr "${HP_RULES}"
        mkdir -p "${HP_RULES}"

        git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" "${HP_RULES}"
        cd "${HP_RULES}" && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")
        
        echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
        awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
        sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt

        mv -f ${HP_RULES}/{china_*,gfw_list}.{ver,txt} ${HP_PATCH}/resources/

        cd .. && rm -rf "${HP_RULES}"

        echo "【Lin】homeproxy date has been updated!"
    fi 
fi






