#!/bin/bash

# 说明：
# 1. 该脚本在 OpenWrt 的 package 目录下执行，用于删除、替换和修补第三方插件包。
# 2. 入口职责保持不变：先按源码风味应用包清单，再执行一组编译兼容性修补。
# 3. 结构上拆成三层：通用包操作函数、源码风味包清单、后置修补函数。

current_script_dir=$(cd "$(dirname "$0")" && pwd)
echo "【Lin】脚本目录：${current_script_dir}"

source_flavor_helper="${current_script_dir}/lib/source_flavor.sh"
[ -f "${source_flavor_helper}" ] && . "${source_flavor_helper}"

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

echo "【Lin】工作目录：${package_workdir}"

find_package_dirs() {
    local package_name=$1

    find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$package_name" 2>/dev/null
}

normalize_repo_url() {
    local package_repo=$1

    if [[ "${package_repo}" == *github.com* ]]; then
        printf '%s\n' "${package_repo}"
    else
        printf 'https://github.com/%s.git\n' "${package_repo}"
    fi
}

clone_repo_shallow() {
    local repo_url=$1
    local repo_branch=$2
    local repo_name=$3

    git clone --depth=1 --single-branch --branch "${repo_branch}" "${repo_url}" "${repo_name}"
}

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
    echo "【Lin】成功clone插件：${package_name} [库：${repo_name}]"

    case "${package_special}" in
        pkg)
            search_result_pkg_dir=$(find "./${repo_name}"/*/ -maxdepth 1 -type d -iname "${search_type}" -prune)
            if [ -n "${search_result_pkg_dir}" ]; then
                mv -f "${repo_name}" "${repo_name}_bak"
                cp -rf $(find "./${repo_name}_bak"/*/ -maxdepth 1 -type d -iname "${search_type}" -prune) "./${search_type}"
                rm -rf "./${repo_name}_bak/"
            fi
            ;;
        name)
            mv -f "${repo_name}" "${package_name}"
            echo "【Lin】重命名插件：${package_name} <= ${repo_name}"
            ;;
    esac
}

MOVE_PACKAGE_FROM_LIST() {
    local package_name=$1
    local list_repo=$2
    local found

    found=$(find "./${list_repo}"/*/ -maxdepth 1 -type d -iname "${package_name}" -print)
    if [ -n "${found}" ]; then
        cp -rf ${found} ./
        echo "【Lin】复制插件包库${list_repo}的${package_name}到package中"
    else
        echo "【Lin】未找到插件包库${list_repo}的${package_name}"
    fi
}

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

resolve_packages_source_flavor() {
    if command -v resolve_source_flavor >/dev/null 2>&1; then
        source_flavor=$(resolve_source_flavor "${source_repo_url}")
    else
        source_flavor='lean'
    fi

    echo "【Lin】Packages 源码风味：${source_flavor}"
}

apply_common_package_overrides() {
    update_package_list "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "master"
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
}

apply_lean_package_overrides() {
    UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
    update_package_list "luci-app-wolplus" "sundaqiang/openwrt-packages" "master"
    update_package_list "luci-app-netspeedtest speedtest-cli" "sbwml/openwrt_pkgs" "main"
}

apply_VIKINGYFY_package_overrides() {
    update_package_list "luci-app-timewol" "VIKINGYFY/packages" "main"
    UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
    update_package_list "luci-app-momo momo" "nikkinikki-org/OpenWrt-momo" "main"
    update_package_list "luci-app-nikki nikki" "nikkinikki-org/OpenWrt-nikki" "main"
    UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
    UPDATE_PACKAGE "luci-app-filetransfer" "DustReliant/luci-app-filetransfer" "master"
    update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"
    update_package_list "luci-app-netspeedtest netspeedtest homebox speedtest-cli" "sirpdboy/luci-app-netspeedtest" "master"
}

apply_generic_package_overrides() {
    UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
    UPDATE_PACKAGE "luci-app-filetransfer" "DustReliant/luci-app-filetransfer" "master"
    update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"
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

apply_lang_node_prebuilt_fix() {
    bash "${current_script_dir}/lib/lang_node_prebuilt.sh" "${openwrt_workdir}"
}

update_openvpn_easy_rsa_version() {
    UPDATE_VERSION "openvpn-easy-rsa"
}

trim_passwall_variants() {
    local passwall_makefile

    passwall_makefile=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
    if [ -f "${passwall_makefile}" ]; then
        sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' "${passwall_makefile}"
        sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' "${passwall_makefile}"
        sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' "${passwall_makefile}"
        echo "【Lin】passwall has been fixed!"
    fi
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

fix_tailscale_makefile() {
    local tailscale_makefile

    tailscale_makefile=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
    [ -f "${tailscale_makefile}" ] && sed -i '/\/files/d' "${tailscale_makefile}" && echo "【Lin】tailscale has been fixed!"
}

fix_rust_build() {
    local rust_makefile

    rust_makefile=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
    if [ -f "${rust_makefile}" ]; then
        sed -i 's/ci-llvm=true/ci-llvm=false/g' "${rust_makefile}"
        cd "${package_workdir}" && echo "【Lin】rust has been fixed!"
    fi
}

fix_diskman_makefile() {
    local diskman_makefile="./luci-app-diskman/applications/luci-app-diskman/Makefile"

    if [ -f "${diskman_makefile}" ]; then
        sed -i 's/fs-ntfs/fs-ntfs3/g' "${diskman_makefile}"
        sed -i '/ntfs-3g-utils /d' "${diskman_makefile}"
        cd "${package_workdir}" && echo "【Lin】diskman has been fixed!"
    fi
}

sync_argon_progress_bar() {
    local argon_dir

    argon_dir=$(find ./*/ -maxdepth 3 -type d -iname "luci-theme-argon" -prune)
    [ -n "${argon_dir}" ] && find "${argon_dir}" -type f -name "cascade*" -exec sed -i 's/--bar-bg/--primary/g' {} \; && \
        echo "【Lin】theme-argon has been fixed：修改进度条颜色与主题色一致！"
}

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

ensure_vlmcsd_ini() {
    local app_vlmcsd_dir
    local vlmcsd_ini

    app_vlmcsd_dir=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "luci-app-vlmcsd" -prune)
    echo "【Lin】检索到luci-app-vlmcsd目录：${app_vlmcsd_dir}"
    if [ -n "${app_vlmcsd_dir}" ] && [ -d "${app_vlmcsd_dir}/root/etc/" ] && [ ! -f "${app_vlmcsd_dir}/root/etc/vlmcsd.ini" ]; then
        vlmcsd_ini="${current_script_dir}/patch/vlmcsd.ini"
        [ -f "${vlmcsd_ini}" ] && cp -fr "${vlmcsd_ini}" "${app_vlmcsd_dir}/root/etc/vlmcsd.ini" && echo "【Lin】预置vlmcsd.ini成功！"
    fi
}

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

apply_post_update_fixes() {
    fix_quickfile_makefile
    apply_lang_node_prebuilt_fix
    update_openvpn_easy_rsa_version
    trim_passwall_variants
    trim_ssrplus_variants
    fix_tailscale_makefile
    fix_rust_build
    fix_diskman_makefile
    sync_argon_progress_bar
    fix_pushbot_runtime
    fix_wechatpush_runtime
    ensure_vlmcsd_ini
    preload_homeproxy_resources
}

main() {
    resolve_packages_source_flavor
    apply_common_package_overrides
    apply_source_flavor_package_overrides
    apply_post_update_fixes
}

main
