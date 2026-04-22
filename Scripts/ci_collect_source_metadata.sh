#!/bin/bash
# 说明：
# 1. 在 make defconfig 之前，从 .config 与源码树推导目标平台、设备列表和内核版本。
# 2. 输出 shell 变量片段，供 GitHub Actions 后续步骤直接导入。

set -euo pipefail

# 内核版本说明：
# 1. 先按目标平台实际使用的 KERNEL_PATCHVER（如 6.12）定位内核版本线。
# 2. 再去 include/kernel-<patchver> 或 target/linux/generic/kernel-<patchver> 里找精确补丁号（如 6.12.80）。
# 3. 如果源码树里暂时没有精确补丁号文件，则至少回退到版本线（如 6.12），避免元信息为空。

extract_kernel_patchver() {
    local makefile_path=$1

    [ -f "${makefile_path}" ] || return 0
    grep -E "KERNEL_PATCHVER[:=]+" "${makefile_path}" | awk -F ':=' '{print $2}' | tr -d ' ' | head -n1
}

extract_kernel_version() {
    local openwrt_root=$1
    local kernel_patchver=$2
    local kernel_file_detail=""
    local version_kernel=""

    for candidate in \
        "${openwrt_root}/include/kernel-${kernel_patchver}" \
        "${openwrt_root}/target/linux/generic/kernel-${kernel_patchver}"; do
        if [ -f "${candidate}" ]; then
            kernel_file_detail="${candidate}"
            break
        fi
    done

    if [ -n "${kernel_file_detail}" ]; then
        version_kernel="$(sed -nE 's/^LINUX_KERNEL_HASH-([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "${kernel_file_detail}" | head -n 1)"
    fi

    if [ -n "${version_kernel}" ]; then
        printf '%s\n' "${version_kernel}"
    else
        printf '%s\n' "${kernel_patchver}"
    fi
}

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
config_path="${openwrt_path}/.config"
wrt_repo_url="${WRT_REPO_URL:?WRT_REPO_URL is required}"
wrt_repo_branch="${WRT_REPO_BRANCH:?WRT_REPO_BRANCH is required}"

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
makefile_path="${dir_linux_device_target}/Makefile"
kernel_patchver="$(extract_kernel_patchver "${makefile_path}")"

if [ -z "${kernel_patchver}" ]; then
    kernel_patchver="6.1"
fi

version_kernel="$(extract_kernel_version "${openwrt_path}" "${kernel_patchver}")"

cat <<EOF
WRT_VER=${wrt_ver}
SOURCE_REPO=${source_repo}
DEVICE_TARGET=${device_target}
DEVICE_SUBTARGET=${device_subtarget}
DEVICE_PROFILE=${device_profile}
DEVICE_NAME_LIST=${device_name_list_joined}
DEVICE_NAME_LIST_LIAN=${device_name_list_lian}
VERSION_KERNEL=${version_kernel}
EOF
