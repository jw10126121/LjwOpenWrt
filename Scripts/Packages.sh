#!/bin/bash


# 运行在openwrt/package目录下
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【Lin】脚本目录：${current_script_dir}"

if [ $(basename "$(pwd)") != 'package' ]; then
    if [ -d "./package" ]; then
        cd ./package
    else
        echo "【Lin】请在package目录下执行，当前工作目录：$(pwd)" 
        exit 0;
    fi
fi

current_dir=$(pwd)
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【Lin】工作目录：${current_dir}"
current_dirname=$(basename "${current_dir}")

openwrt_workdir="$(readlink -f ..)"
package_workdir="${openwrt_workdir}/package"

is_code_lean=true
file_default_settings="./lean/default-settings/files/zzz-default-settings"
if [ -f "$file_default_settings" ]; then
  is_code_lean=true
else
  is_code_lean=false
fi

#删除软件包
DELETE_PACKAGE() {

    local PKG_NAME=$1
    
    local FOUND_DIRS=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" 2>/dev/null)
    # 删除找到的目录
    if [ -n "$FOUND_DIRS" ]; then
        while read -r DIR; do
            rm -rf "$DIR"
            echo "【Lin】删除文件夹：$DIR"
        done <<< "$FOUND_DIRS"
    else
        echo "【Lin】未找到文件夹：$PKG_NAME"
    fi
    # rm -rf $(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    # echo "【Lin】删除插件：$PKG_NAME"
}

# 删除并备份插件(包名是文件夹名)
DELETE_AND_BACKUP_PACKAGE() {
    local PKG_NAME=$1
    path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    path_default_bak="${path_default}_bak"
    [ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
    [ -d "$path_default" ] && mv -f ${path_default} ${path_default_bak} && echo "【Lin】备份${PKG_NAME}：${path_default} -> ${path_default_bak}"
}

# 删除备份的包(包名是文件夹名)
DELETE_BACKUP_PACKAGE() {
    local PKG_NAME=$1
    path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    path_default_bak="${path_default}_bak"
    [ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
}

#安装和更新软件包
UPDATE_PACKAGE() {
    PKG_NAME=$1
    PKG_REPO=$2
    PKG_BRANCH=$3
    PKG_SPECIAL=$4
    searchType="$PKG_NAME"

    # 删除原本同名的软件包
    # local the_exist_pkg=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$searchType" -prune)
    # if [ -n "$the_exist_pkg" ]; then
    #     echo "【Lin】删除同名插件：$the_exist_pkg"
    #     rm -rf $the_exist_pkg
    # fi

    DELETE_PACKAGE "${PKG_NAME}"

    if [[ $PKG_REPO == *github.com* ]]; then
        the_full_repo=$PKG_REPO
    else
        the_full_repo="https://github.com/${PKG_REPO}.git"
    fi

    REPO_URL_git=${the_full_repo%.git}; 
    REPO_NAME=${REPO_URL_git##*/}

    git clone --depth=1 --single-branch --branch $PKG_BRANCH "${the_full_repo}" "${REPO_NAME}"
    echo "【Lin】成功clone插件：$PKG_NAME [库：${REPO_NAME}]"
    if [[ $PKG_SPECIAL == "pkg" ]]; then
        search_result_pkg_dir=$(find ./${REPO_NAME}/*/ -maxdepth 1 -type d -iname "$searchType" -prune)
        if [ -n "${search_result_pkg_dir}" ]; then
            mv -f "$REPO_NAME" "${REPO_NAME}_bak"
            cp -rf $(find ./${REPO_NAME}_bak/*/ -maxdepth 1 -type d -iname "$searchType" -prune) ./$searchType
            rm -rf ./${REPO_NAME}_bak/
        fi
    elif [[ $PKG_SPECIAL == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
        echo "【Lin】重命名插件：$PKG_NAME <= $REPO_NAME"
    fi
}

# 安装和更新同一个仓库下的软件包
UPDATE_PACKAGE_FROM_REPO() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3

    # 删除原本同名的软件包
    the_exist_pkg=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    if [ -n "$the_exist_pkg" ]; then
        echo "【Lin】删除同名插件包库：$the_exist_pkg"
        rm -rf $the_exist_pkg
    fi

    # Clone插件
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" $PKG_NAME
    echo "【Lin】成功clone插件包库：$PKG_NAME"
    echo ""
}

MOVE_PACKAGE_FROM_LIST() {
    local PKG_NAME=$1
    local LIST_REPO=$2

    found=$(find ./"$LIST_REPO"/*/ -maxdepth 1 -type d -iname "$PKG_NAME" -print)
    if [ $? -eq 0 ]; then
        cp -rf $found ./
        echo "【Lin】复制插件包库${LIST_REPO}的${PKG_NAME}到package中"
    else
        echo "【Lin】未找到插件包库${LIST_REPO}的${PKG_NAME}"
    fi
}

# 从库集中添加多个库
update_package_list() {

    pkg_name_list=($1)
    pkg_repo=$2
    pkg_branch=$3

        # 使用for循环遍历数组
    for pkg_name in "${pkg_name_list[@]}"; do
        DELETE_PACKAGE "$pkg_name"
    done

    if [[ $pkg_repo == http* ]]; then
        the_full_repo=$pkg_repo
    else
        the_full_repo="https://github.com/${pkg_repo}.git"
    fi

    # 获取仓库名
    REPO_URL_git=${the_full_repo%.git}; 
    REPO_NAME_LAST=${REPO_URL_git##*/}

    # 获取用户名_仓库名
    REPO_NAME=${the_full_repo#*//}  # 删除前面的协议部分
    REPO_NAME=${REPO_NAME#*/}       # 删除第一个/后面的内容，保留用户名和仓库名
    REPO_NAME=${REPO_NAME%.git}     # 删除后面的.git
    REPO_NAME=${REPO_NAME//\//_}    # 将所有的/替换为_，最终的结果是：作者名_仓库名
    REPO_NAME="pkglist_${REPO_NAME:-$REPO_NAME_LAST}"

    # REPO_NAME="pkglist_$(sed 's#.*/\([^/]*\)/\([^/.]*\)\.git#\1_\2#' <<<"$the_full_repo")" # 以上代码可以精简成这句


    exist_pkg_list=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$REPO_NAME" -prune)
    if [ -n "$exist_pkg_list" ]; then
        echo "【Lin】删除同名插件包库：${exist_pkg_list}"
        rm -rf "${exist_pkg_list}"
    fi
    echo "【Lin】下载插件库${REPO_NAME}：【${pkg_branch}】${the_full_repo}"
    git clone --depth=1 --single-branch --branch $pkg_branch "${the_full_repo}" ${REPO_NAME}
    echo "【Lin】成功clone插件包库：${REPO_NAME}"

    # 使用for循环遍历数组
    for pkg_name in "${pkg_name_list[@]}"; do
        MOVE_PACKAGE_FROM_LIST "${pkg_name}" "${REPO_NAME}"
    done

    echo "【Lin】删除插件包库：${REPO_NAME}"
    rm -rf ${REPO_NAME}

}

safe_update_package() {
    package_name=$1
    pkg_repo=$2
    pkg_branch=$3
    path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "${package_name}" -prune)
    path_default_bak="${path_default}_bak"
    [ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
    [ -d "$path_default" ] && mv -f ${path_default} ${path_default_bak} && echo "【Lin】备份frp：${path_default} -> ${path_default_bak}"
    git clone --depth=1 --single-branch -b "${pkg_branch}" "${pkg_repo}" ${path_default}
    if [ -d ${path_default} ]; then
         echo "【Lin】替换${package_name}成功：${path_default}"
         [ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
    else
        mv -f "${path_default_bak}" "${path_default}"
        echo "【Lin】替换${package_name}失败，还原${package_name}"
    fi
}

#更新软件包版本
UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

    echo " "

    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi

    echo -e "\n$PKG_NAME version update has started!"

    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
        local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

        local PKG_URL=$([[ $OLD_URL == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

        echo "old version: $OLD_VER $OLD_HASH"
        echo "new version: $NEW_VER $NEW_HASH"

        if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "【Lin】$PKG_FILE version has been updated!"
        else
            echo "【Lin】$PKG_FILE version is already the latest!"
        fi
    done
}

### ---------- 执行 ---------- ###


#UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名" "是否精准搜索插件"

if [ "$is_code_lean" == true ]; then
    UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
    # UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "master"
    update_package_list "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "js"
    #UPDATE_PACKAGE "luci-theme-neobird" "BootLoopLover/luci-theme-neobird" "master" # 不可用
    #UPDATE_PACKAGE "luci-theme-design" "0x676e67/luci-theme-design" "main"

    UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

    # update_package_list: 从插件库列表中下载插件
    update_package_list "luci-app-wolplus" "sundaqiang/openwrt-packages" "master"
    update_package_list "luci-app-onliner" "danchexiaoyang/luci-app-onliner" "main"
    update_package_list "wrtbwmon" "brvphoenix/wrtbwmon" "master"
    update_package_list "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"

    # 应用过滤
    update_package_list "luci-app-oaf oaf open-app-filter" "destan19/OpenAppFilter" "master"

    # 替换frp
    safe_update_package "frp" "https://github.com/user1121114685/frp.git" "main"
    # 更新luci-app-frpc luci-app-frps
    update_package_list "luci-app-frpc luci-app-frps" "superzjg/luci-app-frpc_frps" "main"

    # luci-app-wechatpush依赖wrtbwmon
    UPDATE_PACKAGE "luci-app-wechatpush" "tty228/luci-app-wechatpush" "master"
    # https://github.com/gaoyaxuan/luci-app-pushbot，该项目有在更新，可替换
    UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"

    # luci-app-easytier
    update_package_list "luci-app-easytier easytier" "EasyTier/luci-app-easytier" "main"

    UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"
    UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"

    # update_package_list "luci-app-quickfile quickfile" "sbwml/luci-app-quickfile" "main"
    update_package_list "luci-app-timewol" "VIKINGYFY/packages" "main"

    # UPDATE_PACKAGE "luci-app-netspeedtest" "muink/luci-app-netspeedtest" "master"

else

    UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

    update_package_list "luci-app-momo momo" "nikkinikki-org/OpenWrt-momo" "main"
    update_package_list "luci-app-nikki nikki" "nikkinikki-org/OpenWrt-nikki" "main"

    # UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.3.2"
    UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "v2.4.3"
    update_package_list "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "js"
    #UPDATE_PACKAGE "luci-theme-neobird" "BootLoopLover/luci-theme-neobird" "master" # 不可用
    #UPDATE_PACKAGE "luci-theme-design" "0x676e67/luci-theme-design" "main"

    UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"

    # update_package_list: 从插件库列表中下载插件
    update_package_list "luci-app-onliner" "danchexiaoyang/luci-app-onliner" "main"
    update_package_list "wrtbwmon" "brvphoenix/wrtbwmon" "master"
    update_package_list "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"

    # 应用过滤
    update_package_list "luci-app-oaf oaf open-app-filter" "destan19/OpenAppFilter" "master"

    # 替换frp
    safe_update_package "frp" "https://github.com/user1121114685/frp.git" "main"
    # 更新luci-app-frpc luci-app-frps
    update_package_list "luci-app-frpc luci-app-frps" "superzjg/luci-app-frpc_frps" "main"

    # luci-app-wechatpush依赖wrtbwmon
    UPDATE_PACKAGE "luci-app-wechatpush" "tty228/luci-app-wechatpush" "master"
    # https://github.com/gaoyaxuan/luci-app-pushbot，该项目有在更新，可替换
    UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"

    # luci-app-easytier
    update_package_list "luci-app-easytier easytier" "EasyTier/luci-app-easytier" "main"

    UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"
    UPDATE_PACKAGE "openwrt-bandix" "timsaya/openwrt-bandix" "main"

    UPDATE_PACKAGE "luci-app-filetransfer" "DustReliant/luci-app-filetransfer" "master"
    update_package_list "luci-app-socat" "Lienol/openwrt-package" "main"


    update_package_list "luci-app-netspeedtest netspeedtest homebox speedtest-cli" "sirpdboy/luci-app-netspeedtest" "js"
    # update_package_list "luci-app-quickfile quickfile" "sbwml/luci-app-quickfile" "main"

    # update_package_list "luci-app-wolplus" "sundaqiang/openwrt-packages" "master"
    update_package_list "luci-app-wolplus luci-app-timewol" "VIKINGYFY/packages" "main"

fi


Quickfile_Makefile=$(find ./ -maxdepth 3 -type f -wholename "*/quickfile/Makefile")

if [ -f "${Quickfile_Makefile}" ]; then
    # 下面这句同时兼容 Linux 与 macOS
#     sed -i.bak '/^define Build\/Compile$/,/^endef$/c\
# define Build/Compile\
# \t$(CP) $(PKG_BUILD_DIR)/quickfile-$(if $(CONFIG_aarch64),aarch64_generic,x86_64) \
# \t      $(PKG_BUILD_DIR)/quickfile-$(ARCH_PACKAGES)\
# endef' "${Quickfile_Makefile}"
            sed -i '/\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-\$(ARCH_PACKAGES)/c\
\tif [ "\$(ARCH_PACKAGES)" = "x86_64" ]; then \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-x86_64 \$(1)\/usr\/bin\/quickfile; \\\
\telse \\\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-aarch64_generic \$(1)\/usr\/bin\/quickfile; \\\
\tfi' "$Quickfile_Makefile"
    # sed -i 's|$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickfile-$(ARCH_PACKAGES) $(1)/usr/bin/quickfile|$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickfile-aarch64_generic $(1)/usr/bin/quickfile|' "${Quickfile_Makefile}"
    echo "【Lin】修复quickfile问题： ${Quickfile_Makefile}"
# else
#     echo "【Lin】未找到 quickfile/Makefile"
fi


version_workdir="${openwrt_workdir}"

# 修复lang_node编译问题
config_version=$(grep CONFIG_VERSION_NUMBER "${version_workdir}/.config" | cut -d '=' -f 2 | tr -d '"' | awk '{print $2}')
include_version=$(grep -oP '^VERSION_NUMBER:=.*,\s*\K[0-9]+\.[0-9]+\.[0-9]+(-*)?' "${version_workdir}/include/version.mk" | tail -n 1 | sed -E 's/([0-9]+\.[0-9]+)\..*/\1/')
package_version=$(grep -P '^[^#]*coolsnowwolf/luci' "${version_workdir}/feeds.conf.default" | grep -oP 'openwrt-\K[^;]*')
op_version="${config_version:-${include_version:-${package_version}}}"
if [ -z "$op_version" ]; then
    op_version="24.10"
fi

echo "【Lin】openwrt版本号：${op_version}；config_version：${config_version:-无}；include_version：${include_version:-无}；package_version：${package_version:-无}"
if [ -n "$op_version" ]; then  
    path_node_makefile="${version_workdir}/feeds/packages/lang/node"
    path_node_dir_bak="${version_workdir}/feeds/packages/lang/bak_node"
    [ -d "$path_node_dir_bak" ] && rm -fr "$path_node_dir_bak"
    [ -d "$path_node_makefile" ] && mv -f "$path_node_makefile" "$path_node_dir_bak" && echo "【Lin】备份lang_node：${path_node_makefile} -> ${path_node_dir_bak}"

    git clone -b "packages-$op_version" https://github.com/sbwml/feeds_packages_lang_node-prebuilt "$path_node_makefile"
    if [ ! -d "$path_node_makefile" ]; then
        echo "【Lin】下载失败：packages-${op_version}，下载备用版：packages-${package_version}"
        git clone -b "packages-$package_version" https://github.com/sbwml/feeds_packages_lang_node-prebuilt "$path_node_makefile"
    fi

    if [ -d "$path_node_makefile" ]; then
        echo "【Lin】替换lang_node for openwrt_${op_version}成功：${path_node_makefile}"
        [ -d "$path_node_dir_bak" ] && rm -fr "$path_node_dir_bak"
    else
        mv -f "$path_node_dir_bak" "$path_node_makefile"
        echo "【Lin】替换lang_node for openwrt_${op_version}失败，还原lang_node"
    fi
else
    echo "【Lin】openwrt版本号未知"
fi

# UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
# UPDATE_VERSION "sing-box"
# UPDATE_VERSION "tailscale"
#UPDATE_VERSION "alist"
#修复Openvpnserver一键生成证书
UPDATE_VERSION "openvpn-easy-rsa" 

# 移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
    sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

    echo "【Lin】passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
    sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
    sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

    echo "【Lin】ssr-plus has been fixed!"
fi

# 修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
[ -f "$TS_FILE" ] && sed -i '/\/files/d' "$TS_FILE" && echo "【Lin】tailscale has been fixed!"

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
    echo " "

    sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

    cd $package_workdir && echo "【Lin】rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
    echo " "

    sed -i 's/fs-ntfs/fs-ntfs3/g' $DM_FILE
    sed -i '/ntfs-3g-utils /d' $DM_FILE

    cd $package_workdir && echo "【Lin】diskman has been fixed!"
fi


ARGON_DIR=$(find ./*/ -maxdepth 3 -type d -iname "luci-theme-argon" -prune)
# 修改argon主题进度条颜色与主题色一致
[ -n "${ARGON_DIR}" ] && find "${ARGON_DIR}" -type f -name "cascade*" -exec sed -i 's/--bar-bg/--primary/g' {} \; && echo "【Lin】theme-argon has been fixed：修改进度条颜色与主题色一致！"


# 目前仅lean源码测试过，V佬源码也支持
pushbot_DIR=$(find ./*/ -maxdepth 3 -type d -iname "luci-app-pushbot" -prune)
if [ -n "${pushbot_DIR}" ] && [ -f "${pushbot_DIR}/root/usr/bin/pushbot/pushbot" ]; then
    pushbot_action_file="${pushbot_DIR}/root/usr/bin/pushbot/pushbot"
    # 显示wifi温度
    sed -i 's/local cputemp=`soc_temp`/local cputemp=`tempinfo`/' "${pushbot_action_file}"
    sed -i 's/CPU：\${cputemp}℃/\${cputemp}/' "${pushbot_action_file}"
    # 日志不停报网络断开
    net_fix_test_del=' https://www.qidian.com https://www.douban.com'
    sed -i "s|${net_fix_test_del}||g" "${pushbot_action_file}"
    echo "【Lin】app-pushbot has been fixed"
fi

wechatpush_DIR=$(find ./*/ -maxdepth 3 -type d -iname "luci-app-wechatpush" -prune)
wechatpush_bin="${wechatpush_DIR}/root/usr/share/wechatpush/wechatpush"
if [ -n "${wechatpush_DIR}" ] && [ -f "${wechatpush_bin}" ]; then
    sed -i '/^#/!{/^[[:blank:]]*\[ -z "\$1" \] && get_disk/s/^[[:blank:]]*/#&/;}' "${wechatpush_bin}" && echo "【Lin】微信推送去掉硬盘检查"
    sed -i '\|>"\$output_dir/cputemp"|s/soc_temp/tempinfo/g' "${wechatpush_bin}"
    sed -i 's/$(translate "CPU:") ${cputemp}℃/${cputemp}/g' "${wechatpush_bin}"
    echo "【Lin】微信推送添加CPU和WIFI显示"
    my_config_wechatpush_file="${current_script_dir}/patch/wechatpush_diy.json"
    [ -f "${my_config_wechatpush_file}" ] && cp -p "${my_config_wechatpush_file}" "${wechatpush_DIR}/root/usr/share/wechatpush/api/diy.json" && echo "【Lin】wechatpush的diy.json成功！"
fi

# 修复luci-app-vlmcsd未自带vlmcsd.ini的问题
app_vlmcsd_DIR=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "luci-app-vlmcsd" -prune)
echo "【Lin】检索到luci-app-vlmcsd目录：${app_vlmcsd_DIR}"
if [ -n "${app_vlmcsd_DIR}" ] && [ -d "${app_vlmcsd_DIR}/root/etc/" ] && [ ! -f "${app_vlmcsd_DIR}/root/etc/vlmcsd.ini" ]; then
    my_config_vlmcsd_file="${current_script_dir}/patch/vlmcsd.ini"
    [ -f "${my_config_vlmcsd_file}" ] && cp -fr "${my_config_vlmcsd_file}" "${app_vlmcsd_DIR}/root/etc/vlmcsd.ini" && echo "【Lin】预置vlmcsd.ini成功！"
fi


# echo "【Lin】修改ttyd为免密"
# if [ -f "${current_script_dir}/patch/99_ttyd-nopass.sh" ]; then
#     if [ -d "${package_workdir}/base-files/files/etc/uci-defaults/" ]; then
#        install -Dm755 "${current_script_dir}/patch/99_ttyd-nopass.sh" "${package_workdir}/base-files/files/etc/uci-defaults/99_ttyd-nopass" 
#     fi
#     if [ -d "${package_workdir}/lean/default-settings/files/" ]; then
#         install -Dm755 "${current_script_dir}/patch/99_ttyd-nopass.sh" "${package_workdir}/lean/default-settings/files/99_ttyd-nopass"
#     fi
# fi


###### ------- 以下为备用代码 ---------

# UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon-config" "master"
# UPDATE_PACKAGE "luci-theme-argon" "sbwml/luci-theme-argon" "openwrt-24.10" "pkg"
# UPDATE_PACKAGE "luci-theme-argon-config" "sbwml/luci-theme-argon" "openwrt-24.10" "pkg"
# lean源码不可用：luci-theme-design
# update_package_list "luci-theme-design" "kenzok8/openwrt-packages" "master"
# DELETE_PACKAGE "wrtbwmon"
# DELETE_PACKAGE "luci-app-wrtbwmon"
# DELETE_PACKAGE "luci-app-onliner"
# UPDATE_PACKAGE "luci-app-onliner" "danchexiaoyang/luci-app-onliner" "main" "pkg"
# UPDATE_PACKAGE "wrtbwmon" "brvphoenix/wrtbwmon" "master" "pkg"
# UPDATE_PACKAGE "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master" "pkg"
# UPDATE_PACKAGE "luci-app-netwizard" "kiddin9/luci-app-netwizard" "master"     # 测试不能用，不加
# UPDATE_PACKAGE "luci-app-netspeedtest" "muink/luci-app-netspeedtest" "master"

#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

# UPDATE_PACKAGE "luci-app-wolplus" "VIKINGYFY/packages" "main" "pkg"
# # 注意，需要luci-app-nlbwmon支持
# # UPDATE_PACKAGE "luci-app-onliner" "selfcan/luci-app-onliner" "master"
#UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
#UPDATE_PACKAGE "ssr-plus" "fw876/helloworld" "master"
#UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "js"
#UPDATE_PACKAGE "mihomo" "morytyann/OpenWrt-mihomo" "main"

# if [[ $WRT_REPO == *"lede"* ]]; then
#   UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main" # 2024年12月3日测试依旧报错
# fi

#UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5"
#UPDATE_PACKAGE "vnt" "lazyoop/networking-artifact" "main" "pkg"
#UPDATE_PACKAGE "easytier" "lazyoop/networking-artifact" "main" "pkg"

# UPDATE_PACKAGE "luci-app-advancedplus" "VIKINGYFY/packages" "main" "pkg"
#UPDATE_PACKAGE "luci-app-gecoosac" "lwb1978/openwrt-gecoosac" "main"
#UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# if [[ $WRT_REPO != *"immortalwrt"* ]]; then
#   UPDATE_PACKAGE "qmi-wwan" "immortalwrt/wwan-packages" "master" "pkg"
# fi

# 预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
    HP_RULE="surge"
    HP_PATH="./homeproxy/root/etc/homeproxy"

    # chmod +x ./$HP_PATH/scripts/*
    rm -rf ./$HP_PATH/resources/*
    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
    cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

    echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt

    sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
    mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

    cd .. && rm -rf ./$HP_RULE/

    echo "【Lin】homeproxy date has been updated!"
fi

