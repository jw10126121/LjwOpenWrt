#!/bin/bash
# 说明：
# 1. 在 make defconfig 之前，从 .config 与源码树推导目标平台、设备列表和内核版本。
# 2. 输出 shell 变量片段，供 GitHub Actions 后续步骤直接导入。

set -euo pipefail

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
config_path="${openwrt_path}/.config"
wrt_repo_url="${WRT_REPO_URL:?WRT_REPO_URL is required}"
wrt_repo_branch="${WRT_REPO_BRANCH:?WRT_REPO_BRANCH is required}"
wrt_is_lean="${WRT_IS_LEAN:-true}"
source_flavor="${SOURCE_FLAVOR:-lean}"

if [ -n "${source_flavor}" ]; then
    if [ "${source_flavor}" = "lean" ]; then
        wrt_is_lean="true"
    else
        wrt_is_lean="false"
    fi
fi

the_repo="${wrt_repo_url%/}"
wrt_ver="${the_repo##*/}-${wrt_repo_branch}"
source_repo="$(echo "${wrt_repo_url}" | awk -F '/' '{print $(NF)}')"

device_name_list=()
device_target=""
device_subtarget=""

while IFS= read -r line; do
    # 同时兼容 CONFIG_TARGET_DEVICE_* 与较旧的 CONFIG_TARGET_*_DEVICE_* 两种写法。
    if [[ $line =~ ^(CONFIG_TARGET_DEVICE_|CONFIG_TARGET_)([^_]+)_([^_]+)_DEVICE_([^=]+)=y$ ]]; then
        device_target="${BASH_REMATCH[2]}"
        device_subtarget="${BASH_REMATCH[3]}"
        device_name_list+=("${BASH_REMATCH[4]}")
    fi
done < "${config_path}"

device_profile="$(IFS=$'、'; echo "${device_name_list[*]}")"
device_name_list_joined="$(IFS=$' '; echo "${device_name_list[*]}")"
device_name_list_lian="$(IFS=$'_and_'; echo "${device_name_list[*]}")"

dir_linux_version="${openwrt_path}/target/linux"
dir_linux_device_target="$(find "${dir_linux_version}" -type d -name "${device_target}" -print -prune)"
kernel_patchver=""
makefile_path="${dir_linux_device_target}/Makefile"

if [ -f "${makefile_path}" ]; then
    kernel_patchver="$(grep -E "KERNEL_PATCHVER[:=]+" "${makefile_path}" | awk -F ':=' '{print $2}' | tr -d ' ')"
fi

if [ -z "${kernel_patchver}" ]; then
    kernel_patchver="6.1"
fi

kernel_file_detail="${openwrt_path}/target/linux/generic/kernel-${kernel_patchver}"
if [ "${wrt_is_lean}" = "true" ]; then
    kernel_file_detail="${openwrt_path}/include/kernel-${kernel_patchver}"
fi

version_kernel=""
if [ -f "${kernel_file_detail}" ]; then
    version_kernel="$(sed -nE 's/^LINUX_KERNEL_HASH-([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "${kernel_file_detail}" | head -n 1)"
fi

cat <<EOF
WRT_VER=${wrt_ver}
SOURCE_REPO=${source_repo}
SOURCE_FLAVOR=${source_flavor:-lean}
DEVICE_TARGET=${device_target}
DEVICE_SUBTARGET=${device_subtarget}
DEVICE_PROFILE=${device_profile}
DEVICE_NAME_LIST=${device_name_list_joined}
DEVICE_NAME_LIST_LIAN=${device_name_list_lian}
VERSION_KERNEL=${version_kernel}
EOF
