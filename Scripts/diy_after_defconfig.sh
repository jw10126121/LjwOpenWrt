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

preload_homeproxy_resources() {
    local choose_type_homeproxy
    local app_homeproxy_dir
    local homeproxy_dir
    local hp_rules
    local hp_patch
    local resource_version

    if [ "${PRELOAD_HOMEPROXY_RESOURCES:-false}" != "true" ]; then
        echo "【Lin】HomeProxy 规则资源预置已关闭"
        return 0
    fi

    choose_type_homeproxy=$(get_config_value "CONFIG_PACKAGE_luci-app-homeproxy")
    app_homeproxy_dir=$(find ./package ./feeds/luci ./feeds/packages -maxdepth 3 -type d -iname "luci-app-homeproxy" -print -quit 2>/dev/null)

    if [ -z "${choose_type_homeproxy}" ] || [ "${choose_type_homeproxy}" = "n" ] || [ ! -d "${app_homeproxy_dir}" ]; then
        echo "【Lin】未启用 luci-app-homeproxy，跳过规则资源预置"
        return 0
    fi

    homeproxy_dir=$(readlink -f "${app_homeproxy_dir}")
    [ -d "${homeproxy_dir}" ] || return 0

    hp_rules="${homeproxy_dir}/root/etc/homeproxy/my_surge"
    hp_patch="${homeproxy_dir}/root/etc/homeproxy"

    chmod +x "${hp_patch}"/scripts/* 2>/dev/null || true
    rm -rf "${hp_patch}/resources"/*
    [ -d "${hp_rules}" ] && rm -fr "${hp_rules}"
    mkdir -p "${hp_rules}"

    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" "${hp_rules}"
    cd "${hp_rules}" && resource_version=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

    echo "${resource_version}" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
    sed 's/^\.//g' direct.txt > china_list.txt
    sed 's/^\.//g' gfw.txt > gfw_list.txt

    mv -f ./{china_*,gfw_list}.{ver,txt} "${hp_patch}/resources/"

    cd "${openwrt_workdir}"
    rm -rf "${hp_rules}"

    echo "【Lin】homeproxy date has been updated!"
}

cd "${openwrt_workdir}"
preload_homeproxy_resources





