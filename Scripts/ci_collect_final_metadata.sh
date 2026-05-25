#!/bin/bash
# 说明：
# 1. 在 make defconfig 之后收集可确定的固件元信息。
# 2. 输出为 shell 变量片段，供 GitHub Actions `source` 或重定向导入。

set -euo pipefail

# 这三个值的职责不同，取值也故意分开：
# 1. OP_VERSION：主源码版本。用于描述当前主源码本体版本，也更适合做包兼容性判断。
# 2. LUCI_VERSION：LuCI feed 版本。仅在 feeds.conf.default 里能解析出明确版本线时单独展示，否则回退到 OP_VERSION。
# 3. VERSION_KERNEL：由上游 source metadata 阶段按目标平台实际内核版本线解析后传入，这里只负责展示。

normalize_version_value() {
    printf '%s\n' "$1" | sed -E 's/^(OpenWrt|ImmortalWrt)[[:space:]]+//' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

is_snapshot_version() {
    [ "$1" = "SNAPSHOT" ]
}

is_release_version() {
    printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+(\.[0-9]+([-.][A-Za-z0-9]+)?)?$'
}

choose_preferred_version() {
    local primary=$1
    local secondary=$2

    if [ -n "${primary}" ] && is_release_version "${primary}"; then
        printf '%s\n' "${primary}"
        return 0
    fi

    if [ -n "${secondary}" ] && is_release_version "${secondary}"; then
        printf '%s\n' "${secondary}"
        return 0
    fi

    if [ -n "${primary}" ] && is_snapshot_version "${primary}"; then
        printf '%s\n' "${primary}"
        return 0
    fi

    if [ -n "${secondary}" ] && is_snapshot_version "${secondary}"; then
        printf '%s\n' "${secondary}"
        return 0
    fi

    printf '%s\n' "${primary:-${secondary}}"
}

map_device_name_alias() {
    local raw_name=$1

    case "${raw_name}" in
        jdcloud_re-ss-01|jdcloud_ax1800pro)
            printf '%s\n' 'jd_ax1800pro'
            ;;
        *)
            printf '%s\n' "${raw_name}"
            ;;
    esac
}

extract_device_profile_from_config() {
    local config_path=$1
    local device_name_list=()
    local line
    local fallback_profile=""

    if [ -n "${DEVICE_PROFILE:-}" ]; then
        fallback_profile="${DEVICE_PROFILE}"
    fi

    while IFS= read -r line; do
        if [[ $line =~ ^(CONFIG_TARGET_DEVICE_|CONFIG_TARGET_)([^_]+)_([^_]+)_DEVICE_([^=]+)=y$ ]]; then
            device_name_list+=("${BASH_REMATCH[4]}")
        fi
    done < "${config_path}"

    if [ ${#device_name_list[@]} -eq 0 ]; then
        printf '%s\n' "${fallback_profile}"
        return
    fi

    printf '%s\n' "$(IFS=$'、'; echo "${device_name_list[*]}")"
}

build_device_name_alias() {
    local raw_list=$1
    local old_ifs raw_name alias joined

    old_ifs=$IFS
    IFS='、'
    set -- $raw_list
    IFS=$old_ifs

    joined=''
    for raw_name in "$@"; do
        [ -n "${raw_name}" ] || continue
        alias="$(map_device_name_alias "${raw_name}")"
        if [ -n "${joined}" ]; then
            joined="${joined}_and_${alias}"
        else
            joined="${alias}"
        fi
    done

    printf '%s\n' "${joined}"
}

extract_config_version() {
    local config_path=$1
    sed -n 's/^CONFIG_VERSION_NUMBER="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${config_path}" | head -n1 | while IFS= read -r line; do
        normalize_version_value "${line}"
    done
}

extract_include_version() {
    local version_file=$1
    local version_value

    version_value="$(sed -nE 's/^VERSION_NUMBER:=.*,[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+(-[^)]*)?).*/\1/p' "${version_file}" | tail -n1 || true)"
    if [ -z "${version_value}" ]; then
        version_value="$(sed -nE 's/^VERSION_NUMBER:=.*\b(SNAPSHOT)\b.*/\1/p' "${version_file}" | tail -n1 || true)"
    fi

    normalize_version_value "${version_value}"
}

extract_luci_version() {
    local feeds_file=$1
    local fallback_version=$2
    local luci_value

    luci_value="$(sed -nE 's|^[^#]*luci.*openwrt-([^;[:space:]]+).*|\1|p' "${feeds_file}" | head -n1 || true)"
    if [ -n "${luci_value}" ]; then
        normalize_version_value "${luci_value}"
        return 0
    fi

    luci_value="$(sed -nE 's|^[^#]*luci[^;]*;([^[:space:]]+).*|\1|p' "${feeds_file}" | head -n1 || true)"
    if [ -n "${luci_value}" ]; then
        luci_value="$(normalize_version_value "${luci_value}")"
        if is_release_version "${luci_value}" || is_snapshot_version "${luci_value}"; then
            printf '%s\n' "${luci_value}"
            return 0
        fi
    fi

    if grep -Eq '^[^#]*src-[^[:space:]]+[[:space:]]+luci([[:space:]]|$)' "${feeds_file}" 2>/dev/null; then
        printf '%s\n' "${fallback_version}"
        return 0
    fi

    return 1
}

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
wrt_default_lanip="${WRT_DEFAULT_LANIP:?WRT_DEFAULT_LANIP is required}"
wrt_has_lite="${WRT_HAS_LITE:-false}"
wrt_has_wifi="${WRT_HAS_WIFI:-true}"
wrt_repo_url="${WRT_REPO_URL:?WRT_REPO_URL is required}"
wrt_repo_branch="${WRT_REPO_BRANCH:?WRT_REPO_BRANCH is required}"
repo_git_hash="${REPO_GIT_HASH:-}"
source_flavor='lean'
device_target="${DEVICE_TARGET:-}"
device_subtarget="${DEVICE_SUBTARGET:-}"
device_arch="$(sed -n 's/^CONFIG_TARGET_ARCH_PACKAGES="\([^"]*\)"/\1/p' "${openwrt_path}/.config" | head -n1 || true)"
config_version="$(extract_config_version "${openwrt_path}/.config")"
include_version="$(extract_include_version "${openwrt_path}/include/version.mk")"
op_version="$(choose_preferred_version "${config_version}" "${include_version}")"
luci_version="$(extract_luci_version "${openwrt_path}/feeds.conf.default" "${op_version}" || true)"
device_profile="$(extract_device_profile_from_config "${openwrt_path}/.config")"
wrt_has_lite_text='[常规版]'
wrt_has_wifi_text='有WIFI'
package_manager='ipk'
package_manager_tag='ipk'
fw_stack='未知'
fw_stack_tag='unknown'
frp_role='未集成'
frp_role_tag='none'
source_flavor_tag="$(printf '%s' "${source_flavor}" | tr '[:upper:]' '[:lower:]')"
device_name_alias="$(build_device_name_alias "${device_profile}")"
start_time_tag="${START_TIME:-D000000_T000000}"

if [ "${wrt_has_lite}" = "true" ]; then
    wrt_has_lite_text='[精简版]'
fi

if [ "${wrt_has_wifi}" != "true" ]; then
    wrt_has_wifi_text='无WIFI'
fi

if [ "${WRT_USE_APK:-false}" = "true" ]; then
    package_manager='apk'
    package_manager_tag='apk'
fi

if grep -q '^CONFIG_PACKAGE_firewall4=y$' "${openwrt_path}/.config" 2>/dev/null && \
   grep -q '^CONFIG_PACKAGE_firewall=y$' "${openwrt_path}/.config" 2>/dev/null; then
    fw_stack='FW3+FW4(冲突)'
    fw_stack_tag='mixed'
elif grep -q '^CONFIG_PACKAGE_firewall4=y$' "${openwrt_path}/.config" 2>/dev/null; then
    fw_stack='FW4'
    fw_stack_tag='fw4'
elif grep -q '^CONFIG_PACKAGE_firewall=y$' "${openwrt_path}/.config" 2>/dev/null; then
    fw_stack='FW3'
    fw_stack_tag='fw3'
fi

if grep -q '^CONFIG_PACKAGE_frpc=y$' "${openwrt_path}/.config" 2>/dev/null && \
   grep -q '^CONFIG_PACKAGE_frps=m$' "${openwrt_path}/.config" 2>/dev/null; then
    frp_role='FRPC'
    frp_role_tag='frpc'
elif grep -q '^CONFIG_PACKAGE_frpc=m$' "${openwrt_path}/.config" 2>/dev/null && \
     grep -q '^CONFIG_PACKAGE_frps=y$' "${openwrt_path}/.config" 2>/dev/null; then
    frp_role='FRPS'
    frp_role_tag='frps'
elif grep -q '^CONFIG_PACKAGE_frpc=y$' "${openwrt_path}/.config" 2>/dev/null && \
     grep -q '^CONFIG_PACKAGE_frps=y$' "${openwrt_path}/.config" 2>/dev/null; then
    frp_role='FRPC+FRPS'
    frp_role_tag='frpc-frps'
elif grep -q '^CONFIG_PACKAGE_frpc=m$' "${openwrt_path}/.config" 2>/dev/null && \
     grep -q '^CONFIG_PACKAGE_frps=m$' "${openwrt_path}/.config" 2>/dev/null; then
    frp_role='安装包'
    frp_role_tag='pkg'
fi

build_variant_tag="${source_flavor_tag}_${fw_stack_tag}_${frp_role_tag}_${package_manager_tag}"

if [ "${wrt_has_wifi}" != "true" ]; then
    output_name_prefix="${source_flavor_tag}_${device_name_alias}_nowifi_${fw_stack_tag}_${frp_role_tag}_${package_manager_tag}_${start_time_tag}"
else
    output_name_prefix="${source_flavor_tag}_${device_name_alias}_${fw_stack_tag}_${frp_role_tag}_${package_manager_tag}_${start_time_tag}"
fi

# 统一拼接给 README / 通知消息使用的固件说明正文。
# 文案仍保持“内核版本 / LUCI版本 / OP版本”，以兼容现有通知与 README，
# 但代码层已经把三者的来源和用途拆开，避免把 LuCI feed 版本与主源码版本混为一谈。
system_content="编译开始：${start_time_tag}

支持设备：${device_profile}
固件类型：${wrt_has_lite_text}
支持平台：${device_target}-${device_subtarget}
源码风味：${source_flavor}
FW环境：${fw_stack}
FRP角色：${frp_role}
设备架构：${device_arch}
内核版本：${VERSION_KERNEL:-}
LUCI版本：${luci_version:-未知}
OP版本：${op_version}
包管理器：${package_manager}
默认地址：${wrt_default_lanip}
默认密码：无 | password
是否wifi：${wrt_has_wifi_text}
源码地址：${wrt_repo_url}
源码分支：${wrt_repo_branch}
源码hash：${repo_git_hash}"

cat <<EOF
DEVICE_ARCH=${device_arch}
LUCI_VERSION=${luci_version}
OP_VERSION=${op_version}
SOURCE_FLAVOR_TAG=${source_flavor_tag}
PACKAGE_MANAGER_TAG=${package_manager_tag}
FW_STACK_TAG=${fw_stack_tag}
FRP_ROLE_TAG=${frp_role_tag}
BUILD_VARIANT_TAG=${build_variant_tag}
DEVICE_NAME_ALIAS=${device_name_alias}
OUTPUT_NAME_PREFIX=${output_name_prefix}
system_content<<EOF_SYSTEM
${system_content}
EOF_SYSTEM
EOF
