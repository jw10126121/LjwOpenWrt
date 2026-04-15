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

prepare_openclash_meta_core() {
    local choose_type_openclash openclash_dir openclash_core_arch openclash_core_url
    local openclash_root_dir openclash_core_dir temp_dir temp_tar

    choose_type_openclash=$(get_config_value "CONFIG_PACKAGE_luci-app-openclash")
    if [ -z "${choose_type_openclash}" ] || [ "${choose_type_openclash}" = "n" ]; then
        echo "【Lin】未启用 luci-app-openclash，跳过 Meta 内核预置"
        return 0
    fi

    openclash_dir=$(find ./package ./feeds/luci ./feeds/packages -maxdepth 3 -type d -iname "luci-app-openclash" -print -quit)
    if [ -z "${openclash_dir}" ] || [ ! -d "${openclash_dir}" ]; then
        echo "【Lin】警告：已启用 luci-app-openclash，但未找到插件目录，跳过 Meta 内核预置"
        return 0
    fi

    case "${cputype_simple}" in
        amd64|arm64)
            openclash_core_arch="${cputype_simple}"
            ;;
        *)
            echo "【Lin】警告：OpenClash Meta 内核暂不支持当前架构 ${cputype:-unknown}，跳过预置"
            return 0
            ;;
    esac

    openclash_root_dir="$(readlink -f "${openclash_dir}")/root/etc/openclash"
    openclash_core_dir="${openclash_root_dir}/core"
    openclash_core_url="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${openclash_core_arch}.tar.gz"

    mkdir -p "${openclash_core_dir}"
    temp_dir=$(mktemp -d "${openwrt_workdir}/tmp/openclash-meta.XXXXXX") || {
        echo "【Lin】警告：无法创建 OpenClash 临时目录，跳过 Meta 内核预置"
        return 0
    }
    temp_tar="${temp_dir}/clash-meta.tar.gz"

    echo "【Lin】开始预置 OpenClash Meta 内核：${openclash_core_arch}"
    if ! curl -fL --connect-timeout 30 --retry 3 --retry-delay 2 -o "${temp_tar}" "${openclash_core_url}"; then
        echo "【Lin】警告：下载 OpenClash Meta 内核失败：${openclash_core_url}"
        rm -rf "${temp_dir}"
        return 0
    fi

    if ! tar -xzf "${temp_tar}" -C "${temp_dir}"; then
        echo "【Lin】警告：解压 OpenClash Meta 内核失败"
        rm -rf "${temp_dir}"
        return 0
    fi

    if [ ! -f "${temp_dir}/clash" ]; then
        echo "【Lin】警告：OpenClash Meta 内核压缩包内未找到 clash 主程序"
        rm -rf "${temp_dir}"
        return 0
    fi

    mv -f "${temp_dir}/clash" "${openclash_core_dir}/clash_meta"
    chmod 0755 "${openclash_core_dir}/clash_meta"
    rm -rf "${temp_dir}"

    echo "【Lin】OpenClash Meta 内核预置完成：${openclash_core_dir}/clash_meta"
    return 0
}

prepare_openclash_meta_core

cd "${openwrt_workdir}"
choose_type_homeproxy=$(grep -m 1 "^CONFIG_PACKAGE_luci-app-homeproxy=" ./.config | awk -F'=' '{print $2}' | tr -d '"')
# homeproxy_DIR=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "luci-app-homeproxy" -prune)
app_homeproxy_dir=$(find ./package ./feeds/luci ./feeds/packages -maxdepth 3 -type d -iname "luci-app-homeproxy" -print -quit 2>/dev/null)
if [ -n "${choose_type_homeproxy}" ] && [ -d "${app_homeproxy_dir}" ]; then

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










