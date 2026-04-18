#!/bin/bash

# 按当前 OpenWrt 版本切换到匹配的预编译 lang/node 仓库，规避 Node.js 原生编译失败。

extract_openwrt_minor_version() {
    printf '%s\n' "$1" | grep -oE '[0-9]+\.[0-9]+' | head -n1
}

resolve_openwrt_versions() {
    local version_workdir=$1
    local config_raw include_raw package_raw

    config_raw=$(sed -n 's/^CONFIG_VERSION_NUMBER="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${version_workdir}/.config" 2>/dev/null | head -n1)
    include_raw=$(sed -nE 's/^VERSION_NUMBER:=.*,[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+(-[^)]*)?).*/\1/p' "${version_workdir}/include/version.mk" 2>/dev/null | tail -n1)
    package_raw=$(sed -nE 's|^[^#]*coolsnowwolf/luci.*openwrt-([^;[:space:]]+).*|\1|p' "${version_workdir}/feeds.conf.default" 2>/dev/null | head -n1)

    CONFIG_VERSION_MINOR=$(extract_openwrt_minor_version "${config_raw}")
    INCLUDE_VERSION_MINOR=$(extract_openwrt_minor_version "${include_raw}")
    PACKAGE_VERSION_MINOR=$(extract_openwrt_minor_version "${package_raw}")
    OPENWRT_VERSION_MINOR="${CONFIG_VERSION_MINOR:-${INCLUDE_VERSION_MINOR:-${PACKAGE_VERSION_MINOR:-}}}"
}

restore_lang_node_dir() {
    local node_dir=$1
    local node_dir_bak=$2

    [ -d "${node_dir}" ] && rm -rf "${node_dir}"
    [ -d "${node_dir_bak}" ] && mv -f "${node_dir_bak}" "${node_dir}"
}

clone_lang_node_branch() {
    local git_bin=$1
    local repo=$2
    local branch=$3
    local node_dir=$4

    [ -z "${branch}" ] && return 1

    echo "【Lin】尝试下载预编译 lang_node：${branch}"
    rm -rf "${node_dir}"

    if "${git_bin}" clone --depth=1 --single-branch -b "${branch}" "${repo}" "${node_dir}"; then
        return 0
    fi

    rm -rf "${node_dir}"
    return 1
}

replace_lang_node_with_prebuilt() {
    local version_workdir=$1
    local node_prebuilt_repo=${LANG_NODE_PREBUILT_REPO:-https://github.com/sbwml/feeds_packages_lang_node-prebuilt}
    local fallback_version=${LANG_NODE_DEFAULT_FALLBACK_VERSION:-24.10}
    local git_bin=${LANG_NODE_GIT_BIN:-git}
    local node_dir="${version_workdir}/feeds/packages/lang/node"
    local node_dir_bak="${version_workdir}/feeds/packages/lang/node.bak"

    resolve_openwrt_versions "${version_workdir}"

    echo "【Lin】openwrt版本号：${OPENWRT_VERSION_MINOR:-未知}；config_version：${CONFIG_VERSION_MINOR:-无}；include_version：${INCLUDE_VERSION_MINOR:-无}；package_version：${PACKAGE_VERSION_MINOR:-无}"

    if [ ! -d "${node_dir}" ]; then
        echo "【Lin】未找到原始 lang_node 目录：${node_dir}"
        return 1
    fi

    if [ -z "${OPENWRT_VERSION_MINOR}" ] && [ -z "${fallback_version}" ]; then
        echo "【Lin】openwrt版本号未知，跳过 lang_node 替换"
        return 1
    fi

    [ -d "${node_dir_bak}" ] && rm -rf "${node_dir_bak}"
    mv -f "${node_dir}" "${node_dir_bak}"
    echo "【Lin】备份lang_node：${node_dir} -> ${node_dir_bak}"

    if clone_lang_node_branch "${git_bin}" "${node_prebuilt_repo}" "packages-${OPENWRT_VERSION_MINOR}" "${node_dir}" || \
       clone_lang_node_branch "${git_bin}" "${node_prebuilt_repo}" "packages-${fallback_version}" "${node_dir}"; then
        rm -rf "${node_dir_bak}"
        echo "【Lin】替换lang_node成功：${node_dir}"
        return 0
    fi

    restore_lang_node_dir "${node_dir}" "${node_dir_bak}"
    echo "【Lin】替换lang_node失败，还原lang_node"
    return 1
}

main() {
    local version_workdir=${1:-}

    if [ -z "${version_workdir}" ]; then
        echo "Usage: $0 <openwrt-workdir>" >&2
        return 1
    fi

    replace_lang_node_with_prebuilt "${version_workdir}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
