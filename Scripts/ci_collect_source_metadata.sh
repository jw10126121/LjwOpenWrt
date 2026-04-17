#!/bin/bash
# Collect metadata available before make defconfig.

set -euo pipefail

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
config_path="${openwrt_path}/.config"
wrt_repo_url="${WRT_REPO_URL:?WRT_REPO_URL is required}"
wrt_repo_branch="${WRT_REPO_BRANCH:?WRT_REPO_BRANCH is required}"
wrt_is_lean="${WRT_IS_LEAN:-true}"

the_repo="${wrt_repo_url%/}"
wrt_ver="${the_repo##*/}-${wrt_repo_branch}"
source_repo="$(echo "${wrt_repo_url}" | awk -F '/' '{print $(NF)}')"

device_name_list=()
device_target=""
device_subtarget=""

while IFS= read -r line; do
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
    version_kernel="$(grep -oP 'LINUX_KERNEL_HASH-\K[0-9]+\.[0-9]+\.[0-9]+' "${kernel_file_detail}" || true)"
fi

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
