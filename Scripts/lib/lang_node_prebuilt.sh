#!/bin/bash

# 用途：
# 1. 检测当前 OpenWrt 源码实际对应的主次版本，例如 24.10、25.12。
# 2. 查询 sbwml/feeds_packages_lang_node-prebuilt 仓库里实际存在的 packages-x.y 分支。
# 3. 选择一个“最兼容”的预编译分支，替换 feeds/packages/lang/node，规避 Node.js 原生编译失败。
# 4. 如果替换失败，则自动恢复原始 lang/node 目录，避免把 feeds 目录弄坏。
#
# 设计约束：
# 1. 该文件保持自包含，不再调用其它 shell 脚本；Packages.sh 只负责调用本文件。
# 2. 优先尊重远端仓库真实存在的分支，而不是盲目相信本地推导出的 OpenWrt 版本号。
# 3. 对 25.12 这类“本地版本更高、但预编译仓库未跟上”的情况，允许回退到兼容的旧分支。
# 4. 对比当前源码更老的版本（例如 23.05），不强行套用 24.10 的预编译结果，直接跳过替换。

### ---------- 日志 ---------- ###

# 输出阶段标题。
# 目的不是增加日志量，而是把运行过程切成几个稳定阶段，
# 这样出现问题时可以直接定位卡在“版本解析”“分支选择”还是“目录替换”。
log_phase() {
    echo "【Lin】[lang_node] $1"
}

# 输出普通说明日志。
# 统一前缀后，Packages.sh 的整体输出更容易扫读，不会和其它插件修补日志混在一起看不出来源。
log_info() {
    echo "【Lin】[lang_node] $1"
}

### ---------- 版本解析 ---------- ###

# 从任意版本字符串中抽取主次版本。
# 例如：
#   24.10.5    -> 24.10
#   openwrt-25.12 -> 25.12
# 该函数只负责“提取”，不负责判断版本是否真的存在。
extract_openwrt_minor_version() {
    printf '%s\n' "$1" | grep -oE '[0-9]+\.[0-9]+' | head -n1
}

# 把 24.10 这类版本转成可比较的整数。
# 例如：
#   24.10 -> 2410
#   25.12 -> 2512
# 这样后续就可以直接用整数比较大小，而不需要自己处理字符串排序问题。
minor_version_to_number() {
    local version=$1
    local major=${version%%.*}
    local minor=${version#*.}

    [ -z "${major}" ] && return 1
    [ -z "${minor}" ] && return 1
    printf '%d\n' "$((10#${major} * 100 + 10#${minor}))"
}

# 从本地 OpenWrt 源码里尽量推导出当前版本。
# 读取顺序：
# 1. .config 中的 CONFIG_VERSION_NUMBER
# 2. include/version.mk 中的 VERSION_NUMBER
# 3. feeds.conf.default 中 luci 分支名里的 openwrt-x.y
#
# 之所以保留三重来源，是因为不同源码树、不同执行时机下，这三处并不总是同时可靠。
# 函数执行后会设置以下全局变量，供后续流程使用：
#   CONFIG_VERSION_MINOR
#   INCLUDE_VERSION_MINOR
#   LUCI_FEED_VERSION_MINOR
#   OPENWRT_VERSION_MINOR
resolve_openwrt_versions() {
    local version_workdir=$1
    local config_raw include_raw luci_feed_raw

    config_raw=$(sed -n 's/^CONFIG_VERSION_NUMBER="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${version_workdir}/.config" 2>/dev/null | head -n1)
    include_raw=$(sed -nE 's/^VERSION_NUMBER:=.*,[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+(-[^)]*)?).*/\1/p' "${version_workdir}/include/version.mk" 2>/dev/null | tail -n1)
    if [ -z "${include_raw}" ]; then
        include_raw=$(sed -nE 's/^VERSION_NUMBER:=.*\b(SNAPSHOT)\b.*/\1/p' "${version_workdir}/include/version.mk" 2>/dev/null | tail -n1)
    fi
    luci_feed_raw=$(sed -nE 's|^[^#]*luci.*openwrt-([^;[:space:]]+).*|\1|p' "${version_workdir}/feeds.conf.default" 2>/dev/null | head -n1)

    CONFIG_VERSION_MINOR=$(extract_openwrt_minor_version "${config_raw}")
    INCLUDE_VERSION_MINOR=$(extract_openwrt_minor_version "${include_raw}")
    LUCI_FEED_VERSION_MINOR=$(extract_openwrt_minor_version "${luci_feed_raw}")
    OPENWRT_VERSION_MINOR="${CONFIG_VERSION_MINOR:-${INCLUDE_VERSION_MINOR:-${LUCI_FEED_VERSION_MINOR:-}}}"

    if [ -z "${OPENWRT_VERSION_MINOR}" ] && \
       grep -Eq '^[^#]*src-[^[:space:]]+[[:space:]]+luci([[:space:]]|$)' "${version_workdir}/feeds.conf.default" 2>/dev/null; then
        OPENWRT_VERSION_MINOR="${LANG_NODE_DEFAULT_FALLBACK_VERSION:-24.10}"
    fi
}

### ---------- 远端分支匹配 ---------- ###

# 查询远端预编译仓库实际有哪些 packages-x.y 分支。
# 返回值是一组换行分隔的主次版本，例如：
#   24.10
#   25.12
# 这样后面选分支时就基于“真实存在的分支”决策，而不是基于假设。
list_lang_node_prebuilt_versions() {
    local git_bin=$1
    local repo=$2

    "${git_bin}" ls-remote --heads "${repo}" 2>/dev/null | \
        sed -n 's#.*refs/heads/packages-\([0-9]\+\.[0-9]\+\)$#\1#p' | \
        sort -uV
}

# 在“当前源码版本”和“远端支持版本列表”之间挑一个最合适的预编译版本。
# 选择规则：
# 1. 优先选 <= 当前版本 的最高可用版本。
#    例如当前是 25.12，远端有 24.10 / 25.12，就选 25.12。
#    例如当前是 25.12，远端只有 24.10，就选 24.10。
# 2. 如果当前版本比所有可用版本都高，则降级选最高可用版本。
# 3. 如果完全选不出来，再退到调用方给的 fallback_version。
#
# 注意：
# 对“当前版本更老，但远端版本更高”的情况不会硬套。
# 比如当前是 23.05，而远端只有 24.10，则这里返回空，让主流程决定跳过替换。
pick_lang_node_prebuilt_version() {
    local detected_version=$1
    local supported_versions=$2
    local fallback_version=$3
    local highest_supported=""
    local best_compatible=""
    local detected_num=""
    local supported_version supported_num highest_num best_num

    [ -n "${detected_version}" ] && detected_num=$(minor_version_to_number "${detected_version}" 2>/dev/null || true)

    for supported_version in ${supported_versions}; do
        supported_num=$(minor_version_to_number "${supported_version}" 2>/dev/null || true)
        [ -z "${supported_num}" ] && continue

        highest_num=$(minor_version_to_number "${highest_supported}" 2>/dev/null || true)
        if [ -z "${highest_supported}" ] || [ "${supported_num}" -gt "${highest_num:-0}" ]; then
            highest_supported="${supported_version}"
        fi

        if [ -n "${detected_num}" ] && [ "${supported_num}" -le "${detected_num}" ]; then
            best_num=$(minor_version_to_number "${best_compatible}" 2>/dev/null || true)
            if [ -z "${best_compatible}" ] || [ "${supported_num}" -gt "${best_num:-0}" ]; then
                best_compatible="${supported_version}"
            fi
        fi
    done

    if [ -n "${best_compatible}" ]; then
        printf '%s\n' "${best_compatible}"
        return 0
    fi

    if [ -n "${detected_num}" ] && [ -n "${highest_supported}" ]; then
        highest_num=$(minor_version_to_number "${highest_supported}" 2>/dev/null || true)
        if [ -n "${highest_num}" ] && [ "${detected_num}" -gt "${highest_num}" ]; then
            printf '%s\n' "${highest_supported}"
            return 0
        fi
    fi

    if [ -n "${fallback_version}" ]; then
        printf '%s\n' "${fallback_version}"
        return 0
    fi

    return 1
}

### ---------- 目录替换与回滚 ---------- ###

# 修正克隆后 Makefile 里的 PKG_BASE。
# 原因是：即使仓库分支名正确，Makefile 中的 PKG_BASE 也可能仍然写着旧值。
# 例如：
#   实际选中了 packages-24.10
#   但 Makefile 里仍残留 PKG_BASE:=packages-23.05
# 这种情况下构建时会去错误的 downloads.openwrt.org 路径取包，所以这里强制对齐。
patch_lang_node_makefile_pkg_base() {
    local node_dir=$1
    local selected_version=$2
    local makefile_path="${node_dir}/Makefile"

    [ -f "${makefile_path}" ] || return 0
    [ -n "${selected_version}" ] || return 0

    sed -i -E "s/^PKG_BASE:=packages-.*/PKG_BASE:=packages-${selected_version}/" "${makefile_path}"
}

# 替换失败时恢复原始 lang/node 目录。
# 这里先删掉失败产生的半成品目录，再把备份目录挪回去，保证 feeds 状态尽量回到调用前。
restore_lang_node_dir() {
    local node_dir=$1
    local node_dir_bak=$2

    [ -d "${node_dir}" ] && rm -rf "${node_dir}"
    [ -d "${node_dir_bak}" ] && mv -f "${node_dir_bak}" "${node_dir}"
}

# 执行一次具体分支的浅克隆。
# 成功返回 0，失败返回 1，并清理掉失败产生的目标目录。
# 这里单独拆成函数，是为了让“尝试某个候选分支”这个动作足够清晰，也便于测试。
clone_lang_node_branch() {
    local git_bin=$1
    local repo=$2
    local branch=$3
    local node_dir=$4

    [ -z "${branch}" ] && return 1

    log_info "尝试下载预编译 lang_node：${branch}"
    rm -rf "${node_dir}"

    if "${git_bin}" clone --depth=1 --single-branch -b "${branch}" "${repo}" "${node_dir}"; then
        return 0
    fi

    rm -rf "${node_dir}"
    return 1
}

### ---------- 主流程 ---------- ###

# 主流程：
# 1. 检测当前 OpenWrt 版本。
# 2. 查询远端预编译仓库支持哪些版本。
# 3. 选出最兼容的预编译分支。
# 4. 备份原始 lang/node。
# 5. 克隆选中的预编译分支并修正 Makefile。
# 6. 成功则删除备份；失败则回滚。
#
# 可通过以下环境变量调整行为：
#   LANG_NODE_PREBUILT_REPO
#     预编译仓库地址，默认 sbwml/feeds_packages_lang_node-prebuilt
#   LANG_NODE_SUPPORTED_PREBUILT_VERSIONS
#     当无法查询远端分支时，手工提供支持版本列表，例如 "24.10 25.12"
#   LANG_NODE_DEFAULT_FALLBACK_VERSION
#     当无法从检测版本与支持列表中选出结果时，提供最终兜底版本
#   LANG_NODE_GIT_BIN
#     指定 git 可执行文件，便于测试中替换
replace_lang_node_with_prebuilt() {
    local version_workdir=$1
    local node_prebuilt_repo=${LANG_NODE_PREBUILT_REPO:-https://github.com/sbwml/feeds_packages_lang_node-prebuilt}
    local configured_supported_versions=${LANG_NODE_SUPPORTED_PREBUILT_VERSIONS:-}
    local fallback_version=${LANG_NODE_DEFAULT_FALLBACK_VERSION:-}
    local git_bin=${LANG_NODE_GIT_BIN:-git}
    local node_dir="${version_workdir}/feeds/packages/lang/node"
    local node_dir_bak="${version_workdir}/feeds/packages/lang/node.bak"
    local supported_versions=""
    local selected_version=""

    log_phase "开始处理 lang_node 预编译替换"

    # 第一步：尽量从本地源码里推导当前 OpenWrt 主次版本。
    log_phase "版本解析"
    resolve_openwrt_versions "${version_workdir}"

    # 第二步：先看远端真实有哪些预编译分支。
    # 如果网络不可用或查询失败，再退回到本地配置里提供的静态支持列表。
    log_phase "分支选择"
    supported_versions=$(list_lang_node_prebuilt_versions "${git_bin}" "${node_prebuilt_repo}" || true)
    [ -z "${supported_versions}" ] && supported_versions="${configured_supported_versions:-24.10}"

    # 第三步：基于“当前版本 + 可用分支”选一个兼容版本。
    selected_version=$(pick_lang_node_prebuilt_version "${OPENWRT_VERSION_MINOR:-}" "${supported_versions}" "${fallback_version}" || true)

    log_info "主源码版本号：${OPENWRT_VERSION_MINOR:-未知}；config_version：${CONFIG_VERSION_MINOR:-无}；include_version：${INCLUDE_VERSION_MINOR:-无}；luci_feed_version：${LUCI_FEED_VERSION_MINOR:-无}；supported_versions：${supported_versions:-无}；prebuilt_version：${selected_version:-无}"

    if [ ! -d "${node_dir}" ]; then
        log_info "未找到原始 lang_node 目录：${node_dir}"
        return 1
    fi

    if [ -z "${selected_version}" ]; then
        log_info "未找到兼容的 lang_node 预编译分支，跳过替换"
        return 1
    fi

    if [ -n "${OPENWRT_VERSION_MINOR}" ] && [ "${selected_version}" != "${OPENWRT_VERSION_MINOR}" ]; then
        log_info "当前版本 ${OPENWRT_VERSION_MINOR} 未直接受支持，改用兼容预编译分支 packages-${selected_version}"
    fi

    # 第四步：正式替换前先备份，保证失败时可回滚。
    log_phase "目录替换"
    [ -d "${node_dir_bak}" ] && rm -rf "${node_dir_bak}"
    mv -f "${node_dir}" "${node_dir_bak}"
    log_info "备份lang_node：${node_dir} -> ${node_dir_bak}"

    # 第五步：克隆选中的分支，并修正 Makefile 中的 PKG_BASE。
    if clone_lang_node_branch "${git_bin}" "${node_prebuilt_repo}" "packages-${selected_version}" "${node_dir}"; then
        patch_lang_node_makefile_pkg_base "${node_dir}" "${selected_version}"
        rm -rf "${node_dir_bak}"
        log_phase "处理完成"
        log_info "替换lang_node成功：${node_dir}"
        return 0
    fi

    # 第六步：任一关键步骤失败，就恢复原始目录。
    restore_lang_node_dir "${node_dir}" "${node_dir_bak}"
    log_phase "处理失败"
    log_info "替换lang_node失败，还原lang_node"
    return 1
}

### ---------- 入口 ---------- ###

# 命令行入口。
# 约定只接受一个参数：OpenWrt 源码根目录。
# 这样 Packages.sh 调用时保持最小接口，不把内部实现细节暴露到外层。
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
