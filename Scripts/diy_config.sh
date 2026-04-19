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

source_flavor_helper="${current_script_dir}/lib/source_flavor.sh"
[ -f "${source_flavor_helper}" ] && . "${source_flavor_helper}"

if [ $(basename "$(pwd)") != 'openwrt' ]; then
    if [ -d "./openwrt" ]; then
        cd ./openwrt
    else
        echo "【Lin】请在openwrt目录下执行，当前工作目录：$(pwd)" 
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
    echo "  -s source_code_info   源码信息，兼容格式：hash|url|branch（不再推荐）"
}

# 检查是否需要显示帮助信息
[[ "$1" == "-h" || "$1" == "--help" ]] && show_help && exit 0

default_name="Linjw"
default_ip="192.168.0.1"
is_reset_password=true
default_theme_name=''
package_manager='ipk'
config_name=''
source_code_info=''
source_repo_url="${WRT_REPO_URL:-}"
source_flavor='lean'

# 解析外部传入的定制参数，后续所有修改都围绕这些参数展开。
while getopts "hi:n:p:t:m:c:s:" opt; do
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
            source_code_info=$OPTARG
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

set_kconfig_value() {
    # 统一维护 .config 里的开关，避免多次追加出互相冲突的同名配置。
    local key=$1
    local value=$2

    if grep -q "^${key}=" "${op_config}" 2>/dev/null; then
        sed -i "s#^${key}=.*#${key}=${value}#g" "${op_config}"
    else
        echo "${key}=${value}" >> "${op_config}"
    fi
}

append_file_snippet() {
    local target_file=$1
    local anchor_pattern=$2
    local marker=$3
    local content=$4
    local temp_file

    [ -f "$target_file" ] || return 0
    grep -qF "$marker" "$target_file" && return 0

    temp_file=$(mktemp)
    printf '\n%s\n' "$content" > "$temp_file"
    sed -i "/${anchor_pattern}/r $temp_file" "$target_file"
    rm -f "$temp_file"
}

append_default_settings_snippet() {
    append_file_snippet "$file_default_settings" "$1" "$2" "$3"
}

build_disable_feed_cmd() {
    local feed_name=$1

    if [ "${package_manager}" = 'apk' ]; then
        printf "[ -f /etc/apk/repositories.d/distfeeds.list ] && sed -i '\\|%s| s|^#*|#|' /etc/apk/repositories.d/distfeeds.list" "${feed_name}"
    else
        printf "[ -f /etc/opkg/distfeeds.conf ] && sed -i 's|^#*src/gz %s|#src/gz %s|' /etc/opkg/distfeeds.conf" "${feed_name}" "${feed_name}"
    fi
}

configure_package_manager_mode() {
    if [ "${package_manager}" = 'apk' ]; then
        set_kconfig_value "CONFIG_USE_APK" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-package-manager" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-opkg" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-lib-ipkg" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-opkg-zh-cn" "n"
        echo "【Lin】包管理器模式：apk（启用新版 LuCI 包管理器）"
    else
        set_kconfig_value "CONFIG_USE_APK" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-package-manager" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn" "n"
        set_kconfig_value "CONFIG_PACKAGE_luci-app-opkg" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-lib-ipkg" "y"
        set_kconfig_value "CONFIG_PACKAGE_luci-i18n-opkg-zh-cn" "y"
        echo "【Lin】包管理器模式：ipk（保留旧版 LuCI 包管理器）"
    fi
}

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

configure_default_system() {
    if find ./package/lean/autocore/files -type f -name 'index.htm' 2>/dev/null | grep -q .; then
        sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' ./package/lean/autocore/files/*/index.htm
        echo "【Lin】修改默认时间格式如：$(date "+%a %Y-%m-%d %H:%M:%S")"
    fi

    if [ -f "$CFG_FILE_OP" ]; then
        sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE_OP"
        sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE_OP"
        echo "【Lin】OP默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
    fi

    if [ -d "./feeds/luci/modules/luci-mod-system/" ]; then
        sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
    fi

    if [ -d "./feeds/luci/modules/luci-mod-status/" ]; then
        sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ ${default_name}-$(date +%Y%m%d)')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
        echo "【Lin】添加编译日期标识成功：${default_name}-$(date +%Y%m%d)"
    fi

    if [ "${is_code_lean}" != true ]; then
        sed -i "s/\[sid\]\.hasOwnProperty/\[sid\]\?\.hasOwnProperty/g" $(find ./feeds/luci/modules/luci-base/ -type f -name "uci.js")
        echo "【Lin】临时修复luci无法保存的问题"
    fi

    if [ -f "$CFG_FILE_LEDE" ]; then
        sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE_LEDE"
        sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE_LEDE"
        echo "【Lin】LEDE默认：IP: ${WRT_IP}，主机名：$WRT_NAME"
    fi
}

resolve_source_flavor_from_input() {
    local parsed_hash parsed_url parsed_branch

    if [ -n "${source_code_info}" ]; then
        IFS='|' read -r parsed_hash parsed_url parsed_branch <<EOF
${source_code_info}
EOF
        if [ -n "${parsed_url}" ]; then
            source_repo_url="${parsed_url}"
        fi
    fi

    if command -v resolve_source_flavor >/dev/null 2>&1; then
        source_flavor=$(resolve_source_flavor "${source_repo_url}")
    else
        source_flavor='lean'
    fi

    if [ "${source_flavor}" = 'lean' ]; then
        is_code_lean=true
    else
        is_code_lean=false
    fi

    echo "【Lin】源码风味：${source_flavor}"
}

configure_common_system_defaults() {
    configure_default_system
    configure_theme
    clear_passwords
    adjust_luci_menu_positions
    configure_openvpn_defaults
    configure_base_package_options
    configure_source_default_settings_package
    patch_apk_empty_feed_indexing
}

configure_theme() {
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

apply_lean_runtime_customizations() {
    local dhcp_ip_start=10
    local dhcp_ip_end=254
    local dhcp_ip_limit=$((dhcp_ip_end - dhcp_ip_start + 1))
    local frp_snippet holdoff_snippet dhcp_snippet remove_sqm_scripts_nss remove_nss_packages

    [ -f "$file_default_settings" ] || return 0

    frp_snippet=$(cat <<'EOF'
[ -f /usr/bin/frpc ] && chmod +x /usr/bin/frpc
[ -f /usr/bin/frps ] && chmod +x /usr/bin/frps
[ -f /etc/init.d/frpc ] && chmod +x /etc/init.d/frpc
[ -f /etc/init.d/frps ] && chmod +x /etc/init.d/frps
EOF
)
    append_default_settings_snippet "uci commit system" "/etc/init.d/frpc" "$frp_snippet"
    if grep -qF '/etc/init.d/frpc' "$file_default_settings"; then
        echo "【Lin】修改frpc、frps执行权限成功！"
    fi

    holdoff_snippet=$(cat <<'EOF'
uci set luci.apply.holdoff=3
uci commit luci
EOF
)
    append_default_settings_snippet "uci commit system" "uci set luci.apply.holdoff" "$holdoff_snippet"
    if grep -qF "uci set luci.apply.holdoff" "$file_default_settings"; then
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
    if grep -qF 'uci set dhcp.@dnsmasq[0].sequential_ip=' "$file_default_settings"; then
        echo "【Lin】设置DHCP顺序分配${dhcp_ip_start}~${dhcp_ip_end}的IP。"
    fi

    remove_sqm_scripts_nss=$(build_disable_feed_cmd "openwrt_sqm_scripts_nss")
    append_default_settings_snippet "helloworld" "$remove_sqm_scripts_nss" "$remove_sqm_scripts_nss"
    if grep -qF "$remove_sqm_scripts_nss" "$file_default_settings"; then
        echo "【Lin】注释feeds中openwrt_sqm_scripts_nss完成"
    else
        echo "【Lin】注释feeds中openwrt_sqm_scripts_nss失败"
    fi

    remove_nss_packages=$(build_disable_feed_cmd "openwrt_nss_packages")
    append_default_settings_snippet "helloworld" "$remove_nss_packages" "$remove_nss_packages"
    if grep -qF "$remove_nss_packages" "$file_default_settings"; then
        echo "【Lin】注释feeds中openwrt_nss_packages完成"
    else
        echo "【Lin】注释feeds中openwrt_nss_packages失败"
    fi
}

patch_apk_empty_feed_indexing() {
    local package_makefile="${1:-./package/Makefile}"
    local temp_file

    [ "${package_manager}" = 'apk' ] || return 0
    [ -f "$package_makefile" ] || return 0
    grep -qF 'set -- *.apk; \' "$package_makefile" && return 0

    temp_file=$(mktemp)
    if ! awk '
        BEGIN { in_block=0; patched=0 }
        {
            if (!in_block && $0 ~ /\$\(STAGING_DIR_HOST\)\/bin\/apk mkndx \\$/) {
                match($0, /^[[:space:]]*/)
                indent = substr($0, RSTART, RLENGTH)
                print indent "set -- *.apk; \\"
                print indent "if [ \"$$1\" = '\''*.apk'\'' ]; then \\"
                print indent ":; \\"
                print indent "else \\"
                print
                in_block = 1
                patched = 1
                next
            }
            if (in_block && $0 ~ /^[[:space:]]*\*\.apk; \\$/) {
                sub(/\*\.apk; \\$/, "$$@; \\")
                print
                next
            }
            if (in_block && $0 ~ /^[[:space:]]*\)$/) {
                print indent "); \\"
                print indent "fi"
                in_block = 0
                next
            }
            print
        }
        END {
            if (in_block) {
                exit 2
            }
            if (!patched) {
                exit 3
            }
        }
    ' "$package_makefile" > "$temp_file"; then
        rm -f "$temp_file"
        echo "【Lin】未找到可修补的 APK 索引块：${package_makefile}"
        return 0
    fi

    mv "$temp_file" "$package_makefile"
    echo "【Lin】已修补空 APK feed 索引：${package_makefile}"
}

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
            show_version_text="v${op_version} by Lin on ${date_version}"
            to_distrib_revision="${show_version_text}"
        else
            to_distrib_revision="R${date_version} by Lin"
        fi
        sed -i "/DISTRIB_REVISION=/s/${distrib_revision}/${to_distrib_revision}/" "${file_default_settings}"
        echo "【Lin】编译信息修改为：${to_distrib_revision}"
    fi
}

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

configure_openvpn_defaults() {
    local wrt_ippart

    wrt_ippart=$(echo "$WRT_IP" | cut -d'.' -f1-3)
    if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
        echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
        echo "【Lin】OpenVPN Server has been fixed and is now accessible on the network!"
    fi

    if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
        echo "  option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
        echo "【Lin】OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
        sed -i "s/192.168.1.1/$wrt_ippart.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
        sed -i "s/192.168.1.0/$wrt_ippart.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
        echo "【Lin】OpenVPN Server has been fixed the default gateway address!"
    fi
}

configure_base_package_options() {
    set_kconfig_value "CONFIG_FEED_helloworld" "n"
    set_kconfig_value "CONFIG_FEED_sqm_scripts_nss" "n"
    set_kconfig_value "CONFIG_FEED_nss_packages" "n"
    set_kconfig_value "CONFIG_PACKAGE_luci" "y"
    set_kconfig_value "CONFIG_LUCI_LANG_zh_Hans" "y"
    configure_package_manager_mode
}

apply_ipq_optimizations() {
    [ "${is_code_lean}" = true ] && return 0
    [[ ${WRT_TARGET} == *"IPQ"* ]] || return 0

    set_kconfig_value "CONFIG_TARGET_OPTIONS" "y"
    set_kconfig_value "CONFIG_TARGET_OPTIMIZATION" "\"-O2 -pipe -march=armv8-a+crypto+crc -mcpu=cortex-a53+crypto+crc -mtune=cortex-a53\""
    set_kconfig_value "CONFIG_FEED_nss_packages" "n"
    set_kconfig_value "CONFIG_FEED_sqm_scripts_nss" "n"
    set_kconfig_value "CONFIG_NSS_FIRMWARE_VERSION_11_4" "n"
    set_kconfig_value "CONFIG_NSS_FIRMWARE_VERSION_12_5" "y"
}

apply_ipq_init_tuning() {
    local nss_drv="./feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
    local nss_pbuf="${package_workdir}/kernel/mac80211/files/qca-nss-pbuf.init"

    [ "${is_code_lean}" = true ] && return 0
    [[ ${WRT_TARGET} == *"IPQ"* ]] || return 0

    if [ -f "$nss_drv" ]; then
        sed -i 's/START=.*/START=85/g' "$nss_drv"
        cd "$package_workdir" && echo "【Lin】qca-nss-drv has been fixed!"
    fi

    if [ -f "$nss_pbuf" ]; then
        sed -i 's/START=.*/START=86/g' "$nss_pbuf"
        cd "$package_workdir" && echo "【Lin】qca-nss-pbuf has been fixed!"
    fi
}

apply_VIKINGYFY_runtime_customizations() {
    echo "【Lin】当前源码风味为 VIKINGYFY，暂未追加专属运行时修补"
}

apply_generic_runtime_defaults() {
    local default_bash_dir='./package/base-files/files/etc/uci-defaults'
    local default_bash_script='./package/base-files/files/etc/uci-defaults/99-lin-defaults'
    local dhcp_ip_start=10
    local dhcp_ip_end=254
    local dhcp_ip_limit=$((dhcp_ip_end - dhcp_ip_start + 1))

    [ "${is_code_lean}" = true ] && return 0

    mkdir -p "$default_bash_dir"
    touch "$default_bash_script"
cat <<EOF > "$default_bash_script"
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

    chmod +x "$default_bash_script"
    echo "【Lin】配置首次运行脚本成功："
    echo "【Lin】1、修改frpc、frps权限"
    echo "【Lin】2、配置dhcp，起：${dhcp_ip_start}，数：${dhcp_ip_limit}"
    echo "【Lin】3、修改luci响应时间3s"
}

main() {
    WRT_TARGET="${config_name}"
    resolve_source_flavor_from_input

    configure_common_system_defaults
    update_build_revision

    case "${source_flavor}" in
        lean)
            apply_lean_runtime_customizations
            configure_nss_usage_display
            ;;
        VIKINGYFY)
            apply_VIKINGYFY_runtime_customizations
            apply_ipq_optimizations
            apply_ipq_init_tuning
            apply_generic_runtime_defaults
            ;;
        *)
            apply_ipq_optimizations
            apply_ipq_init_tuning
            apply_generic_runtime_defaults
            ;;
    esac
}

main
