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
target_label_marker_file="./.linjw-target-label"

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

configure_ecm_accel_delay_fix() {
    local ecm_init_file="./package/qca/qca-nss-ecm/files/qca-nss-ecm.init"
    local ax18_device_config='^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y$'
    local marker_file="${target_label_marker_file:-./.linjw-target-label}"
    local target_label

    [ -f "${ecm_init_file}" ] || return 0
    [ -f "${marker_file}" ] || return 0

    target_label=$(tr -d '\r' < "${marker_file}")
    case "${target_label}" in
        CMIOT-AX18-NOWIFI|CMIOT-AX18-NOWIFI-FW3|CMIOT-AX18-NOWIFI-FW4)
            ;;
        *)
            return 0
            ;;
    esac

    grep -q "${ax18_device_config}" ./.config 2>/dev/null || return 0

    # qca-nss-ecm 默认把 accel_delay_pkts 设为 1，表示双向流量一出现就很快允许加速。
    # AX18 上这会导致微信朋友圈相关连接过早进入 ECM，出现无法刷新的问题。
    # 改为 24 后，连接会先多走少量慢路径包，再进入 ECM；这是当前实机验证可用且
    # 相对保守的最小有效值，比彻底关闭 ECM 或使用极大延迟值的副作用更小。
    sed -i 's#echo 1 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts#echo 24 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts#' "${ecm_init_file}"
    if grep -qF "echo 24 > /sys/kernel/debug/ecm/ecm_classifier_default/accel_delay_pkts" "${ecm_init_file}"; then
        echo "【Lin】已为 CMIOT-AX18-NOWIFI 将 ECM 默认 accel_delay_pkts 调整为 24"
    fi
}

preload_openclash_meta_core() {
    local choose_type_openclash
    local app_openclash_dir
    local openclash_dir
    local core_dir
    local clash_arch
    local target_label

    # 检查 OpenClash 是否启用
    choose_type_openclash=$(get_config_value "CONFIG_PACKAGE_luci-app-openclash")
    app_openclash_dir=$(find ./package ./feeds/luci ./feeds/packages -maxdepth 3 -type d -iname "luci-app-openclash" -print -quit 2>/dev/null)

    if [ -z "${choose_type_openclash}" ] || [ "${choose_type_openclash}" = "n" ] || [ ! -d "${app_openclash_dir}" ]; then
        echo "【Lin】未启用 luci-app-openclash，跳过内核预置"
        return 0
    fi

    # 检查设备是否为 AX6600 或 MT6000（仅这两款大内存设备预置）
    target_label=$(tr -d '\r' < "${target_label_marker_file}" 2>/dev/null || echo "")
    case "${target_label}" in
        JD-AX6600-WIFI*|MT6000-WIFI*)
            ;;
        *)
            echo "【Lin】设备 ${target_label:-未知} 不在预置列表中，跳过 OpenClash 内核预置"
            return 0
            ;;
    esac

    openclash_dir=$(readlink -f "${app_openclash_dir}")
    [ -d "${openclash_dir}" ] || return 0

    # 创建内核目录
    core_dir="${openclash_dir}/root/etc/openclash/core"
    mkdir -p "${core_dir}"

    # 根据架构选择内核
    case "${cputype_simple}" in
        arm64) clash_arch="arm64" ;;
        amd64) clash_arch="amd64" ;;
        *)
            echo "【Lin】不支持的架构：${cputype_simple}，跳过 OpenClash 内核预置"
            return 0
            ;;
    esac

    # 下载 Clash Meta 内核
    local core_url="https://github.com/vernesong/OpenClash/core/raw/master/meta/clash-linux-${clash_arch}"
    echo "【Lin】下载 OpenClash Meta 内核：${core_url}"
    if curl -sL -o "${core_dir}/clash_meta" "${core_url}"; then
        chmod +x "${core_dir}/clash_meta"
        echo "【Lin】OpenClash Meta 内核预置完成"
    else
        echo "【Lin】警告：OpenClash Meta 内核下载失败"
    fi
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
configure_ecm_accel_delay_fix
# preload_openclash_meta_core
#preload_homeproxy_resources



