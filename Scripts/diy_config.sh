#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: Linjw
# 通用的diy配置脚本
# 该脚本在config确认前于openwrt目录下执行
# 主要职责：改默认网络参数、修补 LuCI/插件行为、补充编译选项与首次启动脚本。
#=================================================

work_dir=$(pwd)
# 运行在openwrt目录下
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【Lin】脚本目录：${current_script_dir}"

if [ $(basename "$(pwd)") != 'openwrt' ]; then
    if [ -n "${OPENWRT_PATH:-}" ] && [ -d "${OPENWRT_PATH}" ]; then
        cd "${OPENWRT_PATH}"
    elif [ -d "./openwrt" ]; then
        cd ./openwrt
    else
        echo "【Lin】请在openwrt目录下执行，当前工作目录：$(pwd)，OPENWRT_PATH：${OPENWRT_PATH:-未设置}" 
        exit 0;
    fi
fi

package_workdir="$(pwd)/package"

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
    echo "  -c config_name        配置名，如IPQ60XX-NOWIFI-LEAN"
    echo "  -s wifi_ssid          WiFi名称（vwrt专用）"
    echo "  -w wifi_password      WiFi密码，none表示开放WiFi（vwrt专用）"
}

# 检查是否需要显示帮助信息
[[ "$1" == "-h" || "$1" == "--help" ]] && show_help && exit 0

default_name="Linjw"
default_ip="192.168.0.1"
is_reset_password=true
default_theme_name=''
package_manager='ipk'
config_name=''
WRT_SSID='OpenWrtAP'
WRT_WORD=''

# 解析外部传入的定制参数，后续所有修改都围绕这些参数展开。
while getopts "hi:n:p:t:m:c:s:w:" opt; do
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
        m)
            package_manager=$OPTARG
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
        c)
            config_name=$OPTARG
            ;;
        s)
            WRT_SSID=$OPTARG
            ;;
        w)
            WRT_WORD=$OPTARG
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
# lean.config_generate，这个应该是在feeds后才有的
CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"
# lean.默认配置文件，固件首次刷入后运行
file_default_settings="./package/lean/default-settings/files/zzz-default-settings"
# 通用首次开机脚本，落到 /etc/uci-defaults/99-setup_config
file_setup_config="./package/base-files/files/etc/uci-defaults/99-setup_config"
setup_config_template="${current_script_dir}/patch/99-setup_config.txt"
target_label_marker_file="./.linjw-target-label"

# 源码类型：根据 lean 特有文件自动判断
# 如果存在 ./package/lean/default-settings/files/zzz-default-settings 则为 lean，否则为 vwrt
if [ -f "${file_default_settings}" ]; then
    SOURCE_TYPE="lean"
else
    SOURCE_TYPE="vwrt"
fi
echo "【Lin】源码类型：${SOURCE_TYPE}"

# 设置 .config 中的配置项。
# 如果配置项已存在则修改，不存在则追加，避免多次调用产生重复配置。
# 参数：
#   $1 key - 配置项名称（如 CONFIG_PACKAGE_luci-app-xxx）
#   $2 value - 配置项值（如 y、m、n）
set_kconfig_value() {
    local key=$1
    local value=$2

    if grep -q "^${key}=" "${op_config}" 2>/dev/null; then
        sed -i "s#^${key}=.*#${key}=${value}#g" "${op_config}"
    else
        echo "${key}=${value}" >> "${op_config}"
    fi
}

append_file_snippet() {
    # 通用“安全插入片段”工具：
    # 1. 先检查目标文件是否存在；
    # 2. 再用 marker 判断相同内容是否已经插入过，避免重复追加；
    # 3. 最后把 content 写进临时文件，并在 anchor_pattern 命中的那一行后面插入。
    #
    # 参数约定：
    # $1 target_file：要修改的目标文件
    # $2 anchor_pattern：sed 用来定位插入点的锚点模式
    # $3 marker：用于幂等判断的固定字符串
    # $4 content：要插入的实际文本块
    local target_file=$1
    local anchor_pattern=$2
    local marker=$3
    local content=$4
    local temp_file

    [ -f "$target_file" ] || return 0
    grep -qF "$marker" "$target_file" && return 0

    temp_file=$(mktemp)
    printf '\n%s\n' "$content" > "$temp_file"
    # sed 的 r 命令表示“把文件内容读到当前匹配行后面”，不是 replace。
    sed -i "/${anchor_pattern}/r $temp_file" "$target_file"
    rm -f "$temp_file"
}

# 确保首次开机脚本 99-setup_config 存在且可执行。
# 如果模板存在但目标不存在，则复制模板；目标存在则保留。
ensure_setup_config_script() {
    local setup_dir

    setup_dir=$(dirname "$file_setup_config")
    mkdir -p "$setup_dir"
    [ -f "$setup_config_template" ] || return 0

    if [ ! -f "$file_setup_config" ]; then
        cp "$setup_config_template" "$file_setup_config"
    fi

    chmod +x "$file_setup_config"
}

append_default_settings_snippet() {
    # 首次开机自定义逻辑统一写入 /etc/uci-defaults/99-setup_config，
    # 避免继续把运行时初始化片段塞进 lean 的 zzz-default-settings。
    ensure_setup_config_script
    append_file_snippet "$file_setup_config" "# setup_config hooks" "$2" "$3"
}

# 配置包管理器类型（ipk 或 apk）。
# 根据 package_manager 参数设置对应的 CONFIG 选项，
# 启用对应的 LuCI 包管理器界面并禁用另一个。
configure_package_manager_mode() {
    if [ "${package_manager}" = 'apk' ]; then
        set_kconfig_value "CONFIG_PKG_FORMAT" "apk"
        set_kconfig_value "CONFIG_USE_APK" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-package-manager" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-opkg" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-lib-ipkg" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-opkg-zh-cn" "n"
        echo "【Lin】包管理器模式：apk（启用新版 LuCI 包管理器）"
    else
        set_kconfig_value "CONFIG_PKG_FORMAT" "ipk"
        set_kconfig_value "CONFIG_USE_APK" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-package-manager" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-opkg" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-lib-ipkg" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-opkg-zh-cn" "y"
        echo "【Lin】包管理器模式：ipk（保留旧版 LuCI 包管理器）"
    fi
}

# 配置源码自带的 default-settings 包。
# 仅在 emortal 源码 + APK 模式下启用 default-settings-chn。
configure_source_default_settings_package() {
    local emortal_default_settings="./package/emortal/default-settings/Makefile"

    if [ -f "${emortal_default_settings}" ] && [ "${package_manager}" = 'apk' ]; then
        set_kconfig_value "CONFIG_PACKAGE_default-settings-chn" "y"
        echo "【Lin】检测到 emortal default-settings，APK 模式启用 default-settings-chn"
    else
        set_kconfig_value "CONFIG_PACKAGE_default-settings-chn" "n"
        echo "【Lin】当前源码/包管理器组合不启用 default-settings-chn"
    fi
}

# 配置默认系统参数：IP、主机名、时区、时间格式。
# 同时修改 OP 和 LEDE 两套 config_generate，并设置首次开机时区。
configure_default_system() {
    local timezone_snippet

    # 配置时间格式
    if find ./package/lean/autocore/files -type f -name 'index.htm' 2>/dev/null | grep -q .; then
        sed -i 's/os.date()/os.date("%Y-%m-%d %H:%M:%S")/g' ./package/lean/autocore/files/*/index.htm
        echo "【Lin】修改默认时间格式如：$(date "+%Y-%m-%d %H:%M:%S")"
    fi

    #配置主机名、时区、主机ip
    if [ -f "$CFG_FILE_OP" ]; then
        # 配置IP(lean用)
        sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE_OP"
        sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE_OP"
        sed -i "s/timezone='[^']*'/timezone='CST-8'/g" "$CFG_FILE_OP"
        sed -i "s/zonename='[^']*'/zonename='Asia\\/Shanghai'/g" "$CFG_FILE_OP"
        echo "【Lin】OP默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
    fi

    if [ -f "$CFG_FILE_LEDE" ]; then
        sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE_LEDE"
        sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE_LEDE"
        sed -i "s/timezone='[^']*'/timezone='CST-8'/g" "$CFG_FILE_LEDE"
        sed -i "s/zonename='[^']*'/zonename='Asia\\/Shanghai'/g" "$CFG_FILE_LEDE"
        echo "【Lin】LEDE默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
    fi

    # 配置IP(vwrt用)
    if [ -d "./feeds/luci/modules/luci-mod-system/" ]; then
        sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
    fi

    # 配置编译信息(通用)
    local target_file build_id
    target_file=$(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" 2>/dev/null | head -1)
    if [ -n "$target_file" ]; then
        build_id="${default_name}-$(TZ=UTC-8 date +"%y%m%d")"
        sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ ${build_id}')/g" "$target_file"
        echo "【Lin】编译标识：${build_id}"
    fi

    # lean 源码专用：设置默认时区
    if [ "${SOURCE_TYPE}" = "lean" ]; then
        local timezone_snippet
        timezone_snippet=$(cat <<'EOF'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
EOF
)
        append_default_settings_snippet "uci commit system" "uci set system.@system[0].zonename='Asia/Shanghai'" "$timezone_snippet"
        if [ -f "$file_setup_config" ] && grep -qF "uci set system.@system[0].zonename='Asia/Shanghai'" "$file_setup_config"; then
            echo "【Lin】默认时区已设置为 Asia/Shanghai"
        fi
    fi
}

# 配置通用系统默认值，串联所有基础配置函数。
configure_common_system_defaults() {
    # 配置默认系统参数：IP、主机名、时区、时间格式。
    configure_default_system
    # 配置主题信息
    configure_default_theme
    # 配置路由器密码
    clear_passwords
    # 修改菜单显示
    adjust_luci_menu_positions
    # 配置openvpn
    configure_openvpn_defaults
    configure_base_package_options
    configure_source_default_settings_package
}

# 配置默认 LuCI 主题。
# 在 feeds 中查找指定主题，如果存在则修改默认主题并启用该主题包。
configure_default_theme() {
    local theme_dir

    [ -n "$WRT_THEME" ] || {
        echo "【Lin】使用源码默认主题"
        return 0
    }

    theme_dir=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "luci-theme-${WRT_THEME}" -prune)
    if [ -n "$theme_dir" ]; then
        sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
        set_kconfig_value "CONFIG_PACKAGE_luci-theme-$WRT_THEME" "y"
        echo "【Lin】默认主题：${WRT_THEME}，主题目录：${theme_dir}"
    else
        echo "【Lin】不存在主题【$WRT_THEME】，使用默认主题"
    fi
}

# 配置 argon 主题颜色。
# 在首次开机脚本中注入 uci 命令，设置主题主色和透明度。
configure_argon_theme_color() {
    local theme_argon_dir
    local temp_file

    theme_argon_dir=$(find ./package ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "luci-theme-argon" -prune)
    if [ -n "$theme_argon_dir" ] && ! grep -q "uci commit argon" "${file_default_settings}"; then
        temp_file=$(mktemp)
        cat <<'EOF' > "$temp_file"
if [ ! -f /etc/config/argon ]; then
    touch /etc/config/argon
    uci add argon global
fi
uci set argon.@global[0].primary='#31A1A1'
uci set argon.@global[0].transparency='0.5'
uci commit argon
EOF
        sed -i "/uci commit system/r $temp_file" "${file_default_settings}"
        rm "$temp_file"
    fi

    if grep -q "uci commit argon" "${file_default_settings}"; then
        echo "【Lin】修改argon主题色成功"
    fi
}

# lean 源码专属的运行时定制。
# 修改 LuCI 提交等待时间，配置 DHCP 顺序分配 IP 范围。
apply_lean_runtime_customizations() {
    local dhcp_ip_start=10
    local dhcp_ip_end=254
    local dhcp_ip_limit=$((dhcp_ip_end - dhcp_ip_start + 1))
    local holdoff_snippet dhcp_snippet

    [ -f "$file_default_settings" ] || return 0

    holdoff_snippet=$(cat <<'EOF'
uci set luci.apply.holdoff=3
uci commit luci
EOF
)
    append_default_settings_snippet "uci commit system" "uci set luci.apply.holdoff" "$holdoff_snippet"
    if grep -qF "uci set luci.apply.holdoff" "$file_setup_config"; then
        echo "【Lin】修改luci提交等待时间成功！"
    fi

    dhcp_snippet=$(cat <<EOF
uci set dhcp.@dnsmasq[0].sequential_ip=1
uci set dhcp.lan.start=${dhcp_ip_start}
uci set dhcp.lan.limit=${dhcp_ip_limit}
uci commit dhcp
EOF
)
    append_default_settings_snippet "uci commit system" "uci set dhcp.@dnsmasq[0].sequential_ip=" "$dhcp_snippet"
    if grep -qF 'uci set dhcp.@dnsmasq[0].sequential_ip=' "$file_setup_config"; then
        echo "【Lin】设置DHCP顺序分配${dhcp_ip_start}~${dhcp_ip_end}的IP。"
    fi
}

# 写入编译目标标记文件，用于后续流程识别当前编译的配置名。
write_build_target_marker() {
    local marker_file="${target_label_marker_file:-./.linjw-target-label}"

    [ -n "${config_name}" ] || return 0
    printf '%s\n' "${config_name}" > "${marker_file}"
}

# 修复 armv8 设备 xfsprogs 报错
# sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile


# 清空默认密码。
# 如果 is_reset_password 为 true，则清除 shadow 文件和 lean default-settings 中的 root 密码。
clear_passwords() {
    if [[ -f "./package/base-files/files/etc/shadow" && "$is_reset_password" == "true" ]]; then
        sed -i 's/^root:.*:/root:::0:99999:7:::/' "./package/base-files/files/etc/shadow"
        echo "【Lin】密码已清空：./package/base-files/files/etc/shadow"
    fi

    if [[ -f "${file_default_settings}" && "$is_reset_password" == "true" ]]; then
        sed -i '/\/etc\/shadow$/{/root::0:0:99999:7:::/d;/root:::0:99999:7:::/d}' "${file_default_settings}"
        echo "【Lin】LEAN配置密码已清空：${file_default_settings}"
    fi
}

# vwrt 源码专用：配置无线参数。
# 支持两种无线配置文件格式：
# 1. set-wireless.sh（旧格式）
# 2. mac80211.uc（新格式）
# 参数：WRT_SSID（WiFi名称）、WRT_WORD（WiFi密码，为空或none时保持开放WiFi）
configure_wifi_vwrt() {
    local wifi_sh wifi_uc

    wifi_sh=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null | head -1)
    wifi_uc="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

    if [ -f "$wifi_sh" ]; then
        sed -i "s/BASE_SSID='.*'/BASE_SSID='${WRT_SSID}'/g" "$wifi_sh"
        if [[ -n "${WRT_WORD}" && "${WRT_WORD}" != "none" ]]; then
            sed -i "s/BASE_WORD='.*'/BASE_WORD='${WRT_WORD}'/g" "$wifi_sh"
        else
            sed -i "/BASE_WORD=/d" "$wifi_sh"
        fi
        echo "【Lin】WiFi 配置已写入：${wifi_sh}"
    elif [ -f "$wifi_uc" ]; then
        sed -i "s/ssid='.*'/ssid='${WRT_SSID}'/g" "$wifi_uc"
        sed -i "s/country='.*'/country='CN'/g" "$wifi_uc"
        if [[ -n "${WRT_WORD}" && "${WRT_WORD}" != "none" ]]; then
            sed -i "s/key='.*'/key='${WRT_WORD}'/g" "$wifi_uc"
            sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" "$wifi_uc"
        fi
        echo "【Lin】WiFi 配置已写入：${wifi_uc}"
    else
        echo "【Lin】未找到无线配置文件"
    fi
}

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


# 调整 LuCI 菜单位置。
# 将 ttyd 移到系统菜单，upnp/nlbwmon 移到网络，hd-idle/alist/samba4 移到 NAS。
adjust_luci_menu_positions() {
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
}

# 更新编译版本号。
# 从 .config 和 include/version.mk 提取版本信息，格式化后写入 default-settings 的 DISTRIB_REVISION。
update_build_revision() {
    local openwrt_workdir="."
    local config_version include_version op_version distrib_revision date_version show_version_text to_distrib_revision

    [ -f "${file_default_settings}" ] || return 0

    config_version=$(grep CONFIG_VERSION_NUMBER "${openwrt_workdir}/.config" | cut -d '=' -f 2 | tr -d '"' | awk '{print $2}')
    include_version=$(grep -oP '^VERSION_NUMBER:=.*,\s*\K[0-9]+\.[0-9]+\.[0-9]+(-*)?' "${openwrt_workdir}/include/version.mk" | tail -n 1 | sed -E 's/([0-9]+\.[0-9]+)\..*/\1/')
    op_version="${config_version:-${include_version}}"
    distrib_revision=$(grep "DISTRIB_REVISION=" "${file_default_settings}" | awk -F "'" '{print $2}')

    if [[ -n $distrib_revision ]]; then
        date_version=$(date +"%y%m%d")
        if [ -n "${op_version}" ]; then
            show_version_text="v${op_version}"
            # show_version_text="v${op_version} by Lin on ${date_version}"
            to_distrib_revision="${show_version_text}"
        else
            to_distrib_revision="R${date_version} by Lin"
        fi
        sed -i "/DISTRIB_REVISION=/s/${distrib_revision}/${to_distrib_revision}/" "${file_default_settings}"
        echo "【Lin】编译信息修改为：${to_distrib_revision}"
    fi
}

# 配置 NSS/ECM 连接数显示。
# 修改 usage 脚本，在 CPU/NPU 使用率后显示 ECM 连接数。
configure_nss_usage_display() {
    local usage_file="./package/lean/autocore/files/arm/sbin/usage"

    if [[ -f "${usage_file}" ]]; then
        sed -i '/echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"/c\
            if [ -r "/sys/kernel/debug/ecm/ecm_db/connection_count_simple" ]; then\
                connection_count=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count_simple)\
                echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}, ECM: ${connection_count}"\
            else\
                echo -n "CPU: ${cpu_usage}, NPU: ${npu_usage}"\
            fi' "$usage_file"
        echo "【Lin】配置NSS显示执行完成"
    fi
}

# 配置 OpenVPN 默认参数。
# 根据防火墙版本（fw3/fw4）添加 NAT 规则，修复默认网关地址和重复连接问题。
configure_openvpn_defaults() {
    local wrt_ippart
    local firewall_user_path="./package/network/config/firewall/files/firewall.user"
    local fw4_openvpn_nat_dir="./package/base-files/files/usr/share/nftables.d/chain-post/srcnat"
    local fw4_openvpn_nat_file="${fw4_openvpn_nat_dir}/99-openvpn-masq.nft"
    local fw3_openvpn_nat_rule="iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE"

    wrt_ippart=$(echo "$WRT_IP" | cut -d'.' -f1-3)

    if grep -q '^CONFIG_PACKAGE_firewall=y$' "${op_config}" 2>/dev/null; then
        rm -f "${fw4_openvpn_nat_file}"
        if [ -f "${firewall_user_path}" ] && ! grep -Fq "${fw3_openvpn_nat_rule}" "${firewall_user_path}"; then
            echo "${fw3_openvpn_nat_rule}" >> "${firewall_user_path}"
            echo "【Lin】OpenVPN Server 已追加 FW3 iptables NAT 规则"
        fi
    elif grep -q '^CONFIG_PACKAGE_firewall4=y$' "${op_config}" 2>/dev/null; then
        if [ -f "${firewall_user_path}" ]; then
            sed -i "\|${fw3_openvpn_nat_rule}|d" "${firewall_user_path}"
        fi

        mkdir -p "${fw4_openvpn_nat_dir}"
        cat > "${fw4_openvpn_nat_file}" <<'EOF'
ip saddr 10.8.0.0/24 oifname "br-lan" masquerade comment "OpenVPN server LAN NAT"
EOF
        echo "【Lin】OpenVPN Server 已生成 FW4 nftables NAT 规则"
    fi

    if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
        echo "  option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
        echo "【Lin】OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
        sed -i "s/192.168.1.1/$wrt_ippart.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
        sed -i "s/192.168.1.0/$wrt_ippart.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
        echo "【Lin】OpenVPN Server has been fixed the default gateway address!"
    fi
}

# 配置基础包选项：禁用 helloworld 在线源，启用 LuCI 中文语言包，设置包管理器模式。
configure_base_package_options() {
    # 编译后，软件源里，去掉helloworld在线源
    set_kconfig_value "CONFIG_FEED_helloworld" "n"
    # 设置编译加入luci
    set_kconfig_value "CONFIG_PACKAGE_luci" "y"
    # 设置编译中文语言包
    set_kconfig_value "CONFIG_LUCI_LANG_zh_Hans" "y"
    # 设置编译包管理器模式（ipk/apk）
    configure_package_manager_mode
}

# 主入口：串联所有配置流程。
main() {
    WRT_TARGET="${config_name}"
    echo "【Lin】========== diy_config.sh 调试信息 =========="
    echo "【Lin】源码类型：${SOURCE_TYPE}"
    echo "【Lin】config_name：${config_name}"
    echo "【Lin】file_default_settings 存在：$([ -f "${file_default_settings}" ] && echo '是' || echo '否')"
    echo "【Lin】file_default_settings 路径：$(readlink -f "${file_default_settings}" 2>/dev/null || echo '无法解析')"
    echo "【Lin】当前工作目录：$(pwd)"

    configure_common_system_defaults

    # lean 源码专用：更新编译版本号
    if [ "${SOURCE_TYPE}" = "lean" ]; then
        echo "【Lin】执行 lean 专用：update_build_revision + apply_lean_runtime_customizations"
        update_build_revision
        apply_lean_runtime_customizations
    else
        echo "【Lin】⚠️ SOURCE_TYPE=${SOURCE_TYPE}，跳过 lean 专用函数"
    fi

    # vwrt 源码专用：配置无线参数
    if [ "${SOURCE_TYPE}" = "vwrt" ]; then
        echo "【Lin】执行 vwrt 专用：configure_wifi_vwrt"
        configure_wifi_vwrt
    fi

    write_build_target_marker

    if [ "${SOURCE_TYPE}" = "lean" ]; then
        echo "【Lin】执行 lean 专用：configure_nss_usage_display"
        configure_nss_usage_display
    fi
    echo "【Lin】========== diy_config.sh 调试结束 =========="
}

main
