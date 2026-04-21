#!/bin/bash

# 说明：
# 1. 该脚本在 OpenWrt 的 package 目录下执行，用于删除、替换和修补第三方插件包。
# 2. 入口职责保持不变：先按源码风味应用包清单，再执行一组编译兼容性修补。
# 3. 结构上拆成三层：通用包操作函数、源码风味包清单、后置修补函数。
# 4. 这个脚本不负责 menuconfig 选包，只负责把 package/ 与部分 feeds 中的包替换成指定来源版本。
# 5. 整体策略是“先清理同名包，再拉取目标仓库，再做兼容性修补”，避免不同来源的重复包互相污染。

current_script_dir=$(cd "$(dirname "$0")" && pwd)
echo "【Lin】脚本目录：${current_script_dir}"

# source_flavor 只决定“额外覆盖哪些包”。
# 通用包清单所有源码风味都会执行；源码风味清单只补各自差异。
source_flavor_helper="${current_script_dir}/lib/source_flavor.sh"
[ -f "${source_flavor_helper}" ] && . "${source_flavor_helper}"
luci_feed_helper="${current_script_dir}/lib/luci_feed_compat.sh"
[ -f "${luci_feed_helper}" ] && . "${luci_feed_helper}"

# 允许从仓库根目录执行，脚本会自行切换到 package/；
# 如果当前目录和子目录里都没有 package/，则直接退出，避免误删其它路径。
if [ "$(basename "$(pwd)")" != 'package' ]; then
    if [ -d "./package" ]; then
        cd ./package
    else
        echo "【Lin】请在package目录下执行，当前工作目录：$(pwd)"
        exit 0
    fi
fi

package_workdir=$(pwd)
openwrt_workdir="$(readlink -f ..)"
source_repo_url="${WRT_REPO_URL:-}"
source_flavor='lean'
luci_feed_branch='unknown'

echo "【Lin】工作目录：${package_workdir}"

# 在 package/、feeds/luci/、feeds/packages/ 三个常见来源中查找同名包。
# 这样无论包来自官方 feeds 还是第三方仓库，都能先做统一清理。
find_package_dirs() {
    local package_name=$1

    find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$package_name" 2>/dev/null
}

# 统一把 owner/repo 形式转换成完整 GitHub URL；
# 已经是 github.com 全路径时保持不变，兼容脚本中两种写法。
normalize_repo_url() {
    local package_repo=$1

    if [[ "${package_repo}" == *github.com* ]]; then
        printf '%s\n' "${package_repo}"
    else
        printf 'https://github.com/%s.git\n' "${package_repo}"
    fi
}

# 浅克隆只取目标分支最近一层历史，减小 Actions 拉取体积和时间。
clone_repo_shallow() {
    local repo_url=$1
    local repo_branch=$2
    local repo_name=$3

    git clone --depth=1 --single-branch --branch "${repo_branch}" "${repo_url}" "${repo_name}"
}

# 删除同名包是所有替换动作的第一步。
# 这里按包名删除，而不是按仓库名删除，目的是清掉官方 feeds 与旧第三方来源中的同名目录。
DELETE_PACKAGE() {
    local package_name=$1
    local found_dirs

    found_dirs=$(find_package_dirs "${package_name}")
    if [ -n "${found_dirs}" ]; then
        while read -r dir; do
            rm -rf "${dir}"
            echo "【Lin】删除文件夹：${dir}"
        done <<< "${found_dirs}"
    else
        echo "【Lin】未找到文件夹：${package_name}"
    fi
}

# UPDATE_PACKAGE 适用于“一仓库对应一个包目录”的场景。
# package_special:
# - 空：直接保留仓库原目录名
# - pkg：从大杂烩仓库里抽取指定子目录
# - name：把仓库目录重命名成 package_name
UPDATE_PACKAGE() {
    local package_name=$1
    local package_repo=$2
    local package_branch=$3
    local package_special=${4:-}
    local search_type=$package_name
    local full_repo
    local repo_url_git
    local repo_name
    local search_result_pkg_dir

    DELETE_PACKAGE "${package_name}"

    full_repo=$(normalize_repo_url "${package_repo}")
    repo_url_git=${full_repo%.git}
    repo_name=${repo_url_git##*/}

    clone_repo_shallow "${full_repo}" "${package_branch}" "${repo_name}"
    echo "【Lin】成功clone插件：${package_name} [库：${repo_name} | 分支：${package_branch}]"

    case "${package_special}" in
        pkg)
            # 一些仓库根目录只是包集合，真正要编译的是里面某个子目录。
            # 这里先保留整个仓库，再把目标子目录复制到 package/ 根下。
            search_result_pkg_dir=$(find "./${repo_name}"/*/ -maxdepth 1 -type d -iname "${search_type}" -prune)
            if [ -n "${search_result_pkg_dir}" ]; then
                mv -f "${repo_name}" "${repo_name}_bak"
                cp -rf $(find "./${repo_name}_bak"/*/ -maxdepth 1 -type d -iname "${search_type}" -prune) "./${search_type}"
                rm -rf "./${repo_name}_bak/"
            fi
            ;;
        name)
            # 对仓库名和包名不一致的情况，直接把 clone 下来的目录改成目标包名。
            mv -f "${repo_name}" "${package_name}"
            echo "【Lin】重命名插件：${package_name} <= ${repo_name}"
            ;;
    esac
}

# 用于从“包合集仓库”中逐个拷出需要的目录。
# 这里不移动而是复制，是为了允许一个仓库中提取多个包，最后再统一删除临时仓库目录。
MOVE_PACKAGE_FROM_LIST() {
    local package_name=$1
    local list_repo=$2
    local found

    found=$(find "./${list_repo}" -mindepth 1 -maxdepth 2 -type d -iname "${package_name}" -print | head -n 1)
    if [ -n "${found}" ]; then
        cp -rf "${found}" ./
        echo "【Lin】复制插件包库${list_repo}的${package_name}到package中"
    else
        echo "【Lin】未找到插件包库${list_repo}的${package_name}"
    fi
}

# update_package_list 适用于“一个仓库内维护多个包目录”的场景。
# package_name_list 是空格分隔列表，函数会：
# 1. 先删除所有同名旧包
# 2. 临时克隆包合集仓库
# 3. 按列表逐个复制目标目录到 package/
# 4. 删除临时仓库，避免 package/ 中残留整个合集
update_package_list() {
    local package_name_list=($1)
    local package_repo=$2
    local package_branch=$3
    local full_repo
    local repo_url_git
    local repo_name_last
    local repo_name
    local existing_repo
    local package_name

    for package_name in "${package_name_list[@]}"; do
        DELETE_PACKAGE "${package_name}"
    done

    full_repo=$(normalize_repo_url "${package_repo}")
    repo_url_git=${full_repo%.git}
    repo_name_last=${repo_url_git##*/}
    # 临时仓库目录名转成 pkglist_owner_repo 形式，避免和真实包目录重名。
    repo_name=${full_repo#*//}
    repo_name=${repo_name#*/}
    repo_name=${repo_name%.git}
    repo_name=${repo_name//\//_}
    repo_name="pkglist_${repo_name:-$repo_name_last}"

    existing_repo=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "${repo_name}" -prune)
    if [ -n "${existing_repo}" ]; then
        echo "【Lin】删除同名插件包库：${existing_repo}"
        rm -rf "${existing_repo}"
    fi

    echo "【Lin】下载插件库${repo_name}：【${package_branch}】${full_repo}"
    clone_repo_shallow "${full_repo}" "${package_branch}" "${repo_name}"
    echo "【Lin】成功clone插件包库：${repo_name}"

    for package_name in "${package_name_list[@]}"; do
        MOVE_PACKAGE_FROM_LIST "${package_name}" "${repo_name}"
    done

    echo "【Lin】删除插件包库：${repo_name}"
    rm -rf "${repo_name}"
}

# safe_update_package 适用于“要直接覆盖现有包目录，但失败时必须可回滚”的场景。
# 它比 UPDATE_PACKAGE 更保守：先备份旧目录，再替换，clone 失败则回滚。
safe_update_package() {
    local package_name=$1
    local package_repo=$2
    local package_branch=$3
    local path_default
    local path_default_bak

    path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "${package_name}" -prune)
    path_default_bak="${path_default}_bak"
    [ -d "${path_default_bak}" ] && rm -rf "${path_default_bak}"

    [ -d "${path_default}" ] && mv -f "${path_default}" "${path_default_bak}" && \
        echo "【Lin】备份${package_name}：${path_default} -> ${path_default_bak}"

    git clone --depth=1 --single-branch -b "${package_branch}" "${package_repo}" "${path_default}"
    if [ -d "${path_default}" ]; then
        echo "【Lin】替换${package_name}成功：${path_default}"
        [ -d "${path_default_bak}" ] && rm -rf "${path_default_bak}"
    else
        mv -f "${path_default_bak}" "${path_default}"
        echo "【Lin】替换${package_name}失败，还原${package_name}"
    fi
}

# UPDATE_VERSION 只处理采用 GitHub release/tarball 模式且 Makefile 可自动推导版本号的包。
# 它不会下载源码树，只会改 Makefile 里的 PKG_VERSION 与 PKG_HASH。
UPDATE_VERSION() {
    local package_name=$1
    local package_mark=${2:-false}
    local package_files
    local package_file

    package_files=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/${package_name}/Makefile")
    echo " "

    if [ -z "${package_files}" ]; then
        echo "${package_name} not found!"
        return
    fi

    echo -e "\n${package_name} version update has started!"

    for package_file in ${package_files}; do
        local package_repo
        local package_tag
        local old_ver
        local old_url
        local old_file
        local old_hash
        local package_url
        local new_ver
        local new_url
        local new_hash

        package_repo=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" "${package_file}")
        package_tag=$(curl -sL "https://api.github.com/repos/${package_repo}/releases" | jq -r "map(select(.prerelease == ${package_mark})) | first | .tag_name")

        old_ver=$(grep -Po "PKG_VERSION:=\K.*" "${package_file}")
        old_url=$(grep -Po "PKG_SOURCE_URL:=\K.*" "${package_file}")
        old_file=$(grep -Po "PKG_SOURCE:=\K.*" "${package_file}")
        old_hash=$(grep -Po "PKG_HASH:=\K.*" "${package_file}")

        package_url=$([[ ${old_url} == *"releases"* ]] && echo "${old_url%/}/${old_file}" || echo "${old_url%/}")
        new_ver=$(echo "${package_tag}" | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        new_url=$(echo "${package_url}" | sed "s/\$(PKG_VERSION)/${new_ver}/g; s/\$(PKG_NAME)/${package_name}/g")
        new_hash=$(curl -sL "${new_url}" | sha256sum | cut -d ' ' -f 1)

        echo "old version: ${old_ver} ${old_hash}"
        echo "new version: ${new_ver} ${new_hash}"

        if [[ ${new_ver} =~ ^[0-9].* ]] && dpkg --compare-versions "${old_ver}" lt "${new_ver}"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=${new_ver}/g" "${package_file}"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=${new_hash}/g" "${package_file}"
            echo "【Lin】${package_file} version has been updated!"
        else
            echo "【Lin】${package_file} version is already the latest!"
        fi
    done
}

# 根据 WRT_REPO_URL 推断当前源码风味。
# 这里故意给 lean 兜底，保证在没有 helper 的环境下脚本仍然可执行。
resolve_packages_source_flavor() {
    if command -v resolve_source_flavor >/dev/null 2>&1; then
        source_flavor=$(resolve_source_flavor "${source_repo_url}")
    else
        source_flavor='lean'
    fi

    echo "【Lin】Packages 源码风味：${source_flavor}"
}

resolve_packages_luci_feed_branch() {
    if command -v resolve_luci_feed_branch >/dev/null 2>&1; then
        luci_feed_branch=$(resolve_luci_feed_branch "${openwrt_workdir}/feeds.conf.default")
    else
        luci_feed_branch='unknown'
    fi

    echo "【Lin】LuCI feed 分支：${luci_feed_branch}"
}

# 通用包清单：无论 lean / VIKINGYFY / 其它源码风味，都会执行。
# 这里应该只放“对所有风味都通用”的替换，不要放只在特定源码树中才成立的覆盖。
apply_common_package_overrides() {
    UPDATE_PACKAGE "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "master"
    UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

    update_package_list "luci-app-onliner" "danchexiaoyang/luci-app-onliner" "main"
    update_package_list "wrtbwmon" "brvphoenix/wrtbwmon" "master"
    update_package_list "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"
    update_package_list "luci-app-oaf oaf open-app-filter" "destan19/OpenAppFilter" "master"

    safe_update_package "frp" "https://github.com/jw10126121/openwrt_frp" "main"
    update_package_list "luci-app-frpc luci-app-frps" "superzjg/luci-app-frpc_frps" "main"

    UPDATE_PACKAGE "luci-app-wechatpush" "tty228/luci-app-wechatpush" "master"
    UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"

    update_package_list "luci-app-easytier easytier" "EasyTier/luci-app-easytier" "main"

    UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"
    UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"

    update_package_list "luci-app-vlmcsd vlmcsd" "sbwml/openwrt_pkgs" "main"
    update_package_list "luci-app-socat" "sbwml/openwrt_pkgs" "main"

    # quickfile 当前按需保留，默认不导入。
    # 如果后续重新启用，需要同时确认设备侧是否改成 luci-nginx 路线。
    # update_package_list "luci-app-quickfile quickfile" "sbwml/luci-app-quickfile" "main"
}

# lean 风味额外覆盖。
# 只放 lean 源码树中确实需要替换、且不会和其它风味共享的包。
apply_lean_package_overrides() {
    # 
    
    if is_luci_feed_25_12 "${openwrt_workdir}/feeds.conf.default"; then
        # UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
        update_package_list "luci-theme-argon luci-app-argon-config" "sbwml/luci-theme-argon" "openwrt-25.12"
    else
        # UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
        update_package_list "luci-theme-argon luci-app-argon-config" "sbwml/luci-theme-argon" "openwrt-24.10"
    fi
    
    update_package_list "luci-app-wolplus" "sundaqiang/openwrt-packages" "master"
    update_package_list "luci-app-netspeedtest speedtest-cli" "sbwml/openwrt_pkgs" "main"
}

# VIKINGYFY 风味额外覆盖。
# 这里保留该源码系特有的包来源与替换关系。
apply_VIKINGYFY_package_overrides() {
    update_package_list "luci-app-timewol" "VIKINGYFY/packages" "main"
    UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
    update_package_list "luci-app-momo momo" "nikkinikki-org/OpenWrt-momo" "main"
    update_package_list "luci-app-nikki nikki mihomo-meta mihomo-alpha" "nikkinikki-org/OpenWrt-nikki" "main"
    update_package_list "luci-theme-argon luci-app-argon-config" "sbwml/luci-theme-argon" "openwrt-25.12"
    UPDATE_PACKAGE "luci-app-filetransfer" "DustReliant/luci-app-filetransfer" "master"
    # update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"
    update_package_list "luci-app-netspeedtest netspeedtest homebox speedtest-cli" "sirpdboy/luci-app-netspeedtest" "master"
}

# generic 兜底风味：
# 当源码地址无法识别时，仍然给出一套最保守的覆盖，不让脚本直接失效。
apply_generic_package_overrides() {
    # UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
    update_package_list "luci-theme-argon luci-app-argon-config" "sbwml/luci-theme-argon" "openwrt-24.10"
    UPDATE_PACKAGE "luci-app-filetransfer" "DustReliant/luci-app-filetransfer" "master"
    #update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"
    update_package_list "luci-app-netspeedtest netspeedtest homebox speedtest-cli" "sirpdboy/luci-app-netspeedtest" "master"
}

apply_source_flavor_package_overrides() {
    case "${source_flavor}" in
        lean)
            apply_lean_package_overrides
            ;;
        VIKINGYFY)
            apply_VIKINGYFY_package_overrides
            ;;
        *)
            apply_generic_package_overrides
            ;;
    esac
}

# OpenWrt 25.12 的 LuCI 菜单机制与语言包状态和旧分支不同，这里统一补一层兼容：
# 1. vlmcsd / socat 强制切到带 menu.d 与 ACL 的新版包源，避免旧控制器在 25.12 下不显示。
# 2. accesscontrol / adguardhome 暂时从 coolsnowwolf/luci 的 openwrt-23.05 分支补回。
apply_luci_feed_25_12_package_overrides() {
    if ! is_luci_feed_25_12 "${openwrt_workdir}/feeds.conf.default"; then
        return 0
    fi

    echo "【Lin】检测到 LuCI feed 为 openwrt-25.12，补齐 25.12 兼容包源"

    echo "【Lin】25.12未找到luci-app-accesscontrol，从coolsnowwolf/luci的openwrt-23.05分支获取"
    update_package_list "luci-app-accesscontrol" "coolsnowwolf/luci" "openwrt-23.05"
}

# quickfile 的上游二进制文件名和本地 OpenWrt 架构名并不总是一一对应。
# 这个修补只在 quickfile 已经被导入时生效；当前默认未启用，所以通常会静默跳过。
fix_quickfile_makefile() {
    local quickfile_makefile

    quickfile_makefile=$(find ./ -maxdepth 3 -type f -wholename "*/quickfile/Makefile")
    if [ -f "${quickfile_makefile}" ]; then
        sed -i '/\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-\$(ARCH_PACKAGES)/c\
\tif [ "\$(ARCH_PACKAGES)" = "x86_64" ]; then \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-x86_64 \$(1)\/usr\/bin\/quickfile; \\\
\telse \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-aarch64_generic \$(1)\/usr\/bin\/quickfile; \\\
\tfi' "${quickfile_makefile}"
        echo "【Lin】修复quickfile问题：${quickfile_makefile}"
    fi
}

# 统一调用外部 helper 处理 node 预编译包兼容问题，避免主脚本继续膨胀。
apply_lang_node_prebuilt_fix() {
    if [ "${WRT_USE_APK:-false}" = "true" ]; then
        echo "【Lin】APK 模式跳过 sbwml lang_node 预编译，继续使用官方 lang/node"
        return 0
    fi

    echo "【Lin】尝试使用 sbwml/feeds_packages_lang_node-prebuilt 加速 lang_node 编译"
    if LANG_NODE_PREBUILT_REPO="https://github.com/sbwml/feeds_packages_lang_node-prebuilt" \
        bash "${current_script_dir}/lib/lang_node_prebuilt.sh" "${openwrt_workdir}"; then
        return 0
    fi

    echo "【Lin】未命中可用的 sbwml lang_node 预编译分支，继续使用官方 lang/node"
    return 0
}

find_adguardhome_package_dir() {
    find ./ ../feeds/luci -maxdepth 4 -type d -iname "luci-app-adguardhome" -print | head -n 1
}

package_has_adguardhome_translation_zh() {
    local adguardhome_dir=$1

    [ -n "${adguardhome_dir}" ] || return 1

    find "${adguardhome_dir}/po" -maxdepth 2 -type f \( \
        -path "*/zh_Hans/adguardhome.po" -o \
        -path "*/zh-cn/adguardhome.po" -o \
        -path "*/zh_CN/adguardhome.po" -o \
        -path "*/zh/adguardhome.po" \
    \) -print -quit 2>/dev/null | grep -q .
}

# 25.12 下先尊重当前上游 LuCI 包：
# 如果官方/当前包已经带中文，就保持原样；
# 只有仍然缺中文时，才回退到 coolsnowwolf/luci 的 openwrt-23.05 包实现。
fallback_adguardhome_package_25_12() {
    local adguardhome_dir

    if ! is_luci_feed_25_12 "${openwrt_workdir}/feeds.conf.default"; then
        return 0
    fi

    adguardhome_dir=$(find_adguardhome_package_dir)
    if [ -z "${adguardhome_dir}" ]; then
        echo "【Lin】25.12未找到luci-app-adguardhome目录，跳过 adguardhome 中文检查"
        return 0
    fi

    if package_has_adguardhome_translation_zh "${adguardhome_dir}"; then
        echo "【Lin】当前 luci-app-adguardhome 已带中文，保持现有上游：${adguardhome_dir}"
        return 0
    fi

    echo "【Lin】当前 luci-app-adguardhome 仍缺中文，从 coolsnowwolf/luci 的 openwrt-23.05 分支补回"
    update_package_list "luci-app-adguardhome" "coolsnowwolf/luci" "openwrt-23.05"
}

# 下列函数都属于“后置修补链”：
# 前提是包已经通过前面的覆盖流程存在于 package/ 或 feeds 中，
# 然后再对 Makefile、脚本、资源文件做最小修补，使其更适配当前源码与设备配置。
update_openvpn_easy_rsa_version() {
    UPDATE_VERSION "openvpn-easy-rsa"
}

trim_ssrplus_variants() {
    local ssrplus_makefile

    ssrplus_makefile=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
    if [ -f "${ssrplus_makefile}" ]; then
        sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' "${ssrplus_makefile}"
        sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' "${ssrplus_makefile}"
        sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' "${ssrplus_makefile}"
        echo "【Lin】ssr-plus has been fixed!"
    fi
}

# tailscale 的 Makefile 在部分源码树中会带入不兼容 files 路径，这里直接删掉对应引用。
fix_tailscale_makefile() {
    local tailscale_makefile

    tailscale_makefile=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
    [ -f "${tailscale_makefile}" ] && sed -i '/\/files/d' "${tailscale_makefile}" && echo "【Lin】tailscale has been fixed!"
}

# rust 在某些环境下使用 ci-llvm=true 会额外触发更重的构建路径，这里改成更稳妥的值。
fix_rust_build() {
    local rust_makefile

    rust_makefile=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
    if [ -f "${rust_makefile}" ]; then
        sed -i 's/ci-llvm=true/ci-llvm=false/g' "${rust_makefile}"
        cd "${package_workdir}" && echo "【Lin】rust has been fixed!"
    fi
}

# diskman 针对 ntfs3 做适配，避免旧依赖名在新树里继续触发编译失败。
fix_diskman_makefile() {
    local diskman_makefile="./luci-app-diskman/applications/luci-app-diskman/Makefile"

    if [ -f "${diskman_makefile}" ]; then
        sed -i 's/fs-ntfs/fs-ntfs3/g' "${diskman_makefile}"
        sed -i '/ntfs-3g-utils /d' "${diskman_makefile}"
        cd "${package_workdir}" && echo "【Lin】diskman has been fixed!"
    fi
}

# pushbot / wechatpush 两组修补都属于“运行时兼容性”修补：
# 主要处理温度读取函数、展示文案，以及与当前设备环境不匹配的逻辑。
fix_pushbot_runtime() {
    local pushbot_dir
    local pushbot_action_file
    local net_fix_test_del=' https://www.qidian.com https://www.douban.com'

    pushbot_dir=$(find ./*/ -maxdepth 3 -type d -iname "luci-app-pushbot" -prune)
    if [ -n "${pushbot_dir}" ] && [ -f "${pushbot_dir}/root/usr/bin/pushbot/pushbot" ]; then
        pushbot_action_file="${pushbot_dir}/root/usr/bin/pushbot/pushbot"
        sed -i 's/local cputemp=`soc_temp`/local cputemp=`tempinfo`/' "${pushbot_action_file}"
        sed -i 's/CPU：\${cputemp}℃/\${cputemp}/' "${pushbot_action_file}"
        sed -i "s|${net_fix_test_del}||g" "${pushbot_action_file}"
        echo "【Lin】app-pushbot has been fixed"
    fi
}

fix_wechatpush_runtime() {
    local wechatpush_dir
    local wechatpush_bin
    local wechatpush_config

    wechatpush_dir=$(find ./*/ -maxdepth 3 -type d -iname "luci-app-wechatpush" -prune)
    wechatpush_bin="${wechatpush_dir}/root/usr/share/wechatpush/wechatpush"
    if [ -n "${wechatpush_dir}" ] && [ -f "${wechatpush_bin}" ]; then
        sed -i '/^#/!{/^[[:blank:]]*\[ -z "\$1" \] && get_disk/s/^[[:blank:]]*/#&/;}' "${wechatpush_bin}" && echo "【Lin】微信推送去掉硬盘检查"
        sed -i '\|>"\$output_dir/cputemp"|s/soc_temp/tempinfo/g' "${wechatpush_bin}"
        sed -i 's/$(translate "CPU:") ${cputemp}℃/${cputemp}/g' "${wechatpush_bin}"
        echo "【Lin】微信推送添加CPU和WIFI显示"

        wechatpush_config="${current_script_dir}/patch/wechatpush_diy.json"
        [ -f "${wechatpush_config}" ] && cp -p "${wechatpush_config}" "${wechatpush_dir}/root/usr/share/wechatpush/api/diy.json" && \
            echo "【Lin】wechatpush的diy.json成功！"
    fi
}

# homeproxy 这里不是简单替换包，而是预先把规则资源准备到包目录中。
# 这样最终编译出来的镜像会自带一套规则资源，减少首次使用时的初始化成本。
preload_homeproxy_resources() {
    local homeproxy_dir
    local homeproxy_path
    local homeproxy_rule_dir="./surge"
    local resource_version

    homeproxy_dir=$(find . -maxdepth 3 -type d -iname "homeproxy" -prune | head -n 1)
    [ -n "${homeproxy_dir}" ] || return 0

    homeproxy_path="${homeproxy_dir}/root/etc/homeproxy"
    rm -rf "${homeproxy_path}/resources/"*
    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" "${homeproxy_rule_dir}"
    cd "${homeproxy_rule_dir}" && resource_version=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

    echo "${resource_version}" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
    sed 's/^\.//g' direct.txt > china_list.txt
    sed 's/^\.//g' gfw.txt > gfw_list.txt
    mv -f ./{china_*,gfw_list}.{ver,txt} "../${homeproxy_path}/resources/"

    cd ..
    rm -rf "${homeproxy_rule_dir}"
    echo "【Lin】homeproxy date has been updated!"
}

# 后置修补链的顺序很重要：
# 先修 Makefile / 依赖，再修运行时脚本，再补资源文件。
# 这样可以减少后面的修补建立在“包还没准备好”的状态上。
apply_post_update_fixes() {
    fix_quickfile_makefile
    apply_lang_node_prebuilt_fix
    fallback_adguardhome_package_25_12
    update_openvpn_easy_rsa_version
    trim_ssrplus_variants
    fix_tailscale_makefile
    fix_rust_build
    fix_diskman_makefile
    fix_pushbot_runtime
    fix_wechatpush_runtime
    preload_homeproxy_resources
}

# 主入口保持极简，只负责串联四个阶段：
# 1. 识别源码风味
# 2. 应用通用包覆盖
# 3. 应用源码风味差异覆盖
# 4. 执行后置修补链
main() {
    resolve_packages_source_flavor
    resolve_packages_luci_feed_branch
    apply_common_package_overrides
    apply_source_flavor_package_overrides
    apply_luci_feed_25_12_package_overrides
    apply_post_update_fixes
}

main
