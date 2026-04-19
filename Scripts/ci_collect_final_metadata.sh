#!/bin/bash
# 说明：
# 1. 在 make defconfig 之后收集可确定的固件元信息。
# 2. 输出为 shell 变量片段，供 GitHub Actions `source` 或重定向导入。

set -euo pipefail

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
wrt_default_lanip="${WRT_DEFAULT_LANIP:?WRT_DEFAULT_LANIP is required}"
wrt_has_lite="${WRT_HAS_LITE:-false}"
wrt_has_wifi="${WRT_HAS_WIFI:-true}"
wrt_repo_url="${WRT_REPO_URL:?WRT_REPO_URL is required}"
wrt_repo_branch="${WRT_REPO_BRANCH:?WRT_REPO_BRANCH is required}"
repo_git_hash="${REPO_GIT_HASH:-}"
source_flavor="${SOURCE_FLAVOR:-${WRT_SOURCE_FLAVOR:-lean}}"
device_target="${DEVICE_TARGET:-}"
device_subtarget="${DEVICE_SUBTARGET:-}"
device_arch="$(grep -oP '^CONFIG_TARGET_ARCH_PACKAGES="\K[^"]*' "${openwrt_path}/.config" || true)"
luci_version="$(sed -n 's/^[^#]*luci.*openwrt-\([^;[:space:]]*\).*/\1/p' "${openwrt_path}/feeds.conf.default" || true)"
config_version="$(grep CONFIG_VERSION_NUMBER "${openwrt_path}/.config" | cut -d '=' -f 2 | tr -d '"' | awk '{print $2}' || true)"
include_version="$(sed -nE 's/^VERSION_NUMBER:=.*,[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+(-[^)]*)?).*/\1/p' "${openwrt_path}/include/version.mk" | tail -n 1 || true)"
op_version="${config_version:-${include_version}}"
wrt_has_lite_text='[常规版]'
wrt_has_wifi_text='有WIFI'
package_manager='ipk'
fw_stack='未知'
fw_stack_tag='unknown'
frp_role='未集成'
frp_role_tag='none'
source_flavor_tag="$(printf '%s' "${source_flavor}" | tr '[:upper:]' '[:lower:]')"

if [ "${wrt_has_lite}" = "true" ]; then
    wrt_has_lite_text='[精简版]'
fi

if [ "${wrt_has_wifi}" != "true" ]; then
    wrt_has_wifi_text='无WIFI'
fi

if [ "${WRT_USE_APK:-false}" = "true" ]; then
    package_manager='apk'
fi

if grep -q '^CONFIG_PACKAGE_firewall4=y$' "${openwrt_path}/.config" 2>/dev/null; then
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

build_variant_tag="${source_flavor_tag}_${fw_stack_tag}_${frp_role_tag}"

# 统一拼接给 README / 通知消息使用的固件说明正文。
system_content="支持设备：${DEVICE_PROFILE}
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
FW_STACK_TAG=${fw_stack_tag}
FRP_ROLE_TAG=${frp_role_tag}
BUILD_VARIANT_TAG=${build_variant_tag}
system_content<<EOF_SYSTEM
${system_content}
EOF_SYSTEM
EOF
