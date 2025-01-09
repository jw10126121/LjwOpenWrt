#!/bin/bash


# 运行在openwrt/package目录下
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【LinInfo】脚本目录：${current_script_dir}"

if [ $(basename "$(pwd)") != 'package' ]; then
    if [ -d "./package" ]; then
        cd ./package
    else
        echo "【LinInfo】请在package目录下执行，当前工作目录：$(pwd)" 
        exit 0;
    fi
fi

current_dir=$(pwd)
current_script_dir=$(cd $(dirname $0) && pwd)
echo "【LinInfo】工作目录：${current_dir}"
current_dirname=$(basename "${current_dir}")

openwrt_workdir="$(readlink -f ..)"
package_workdir="${openwrt_workdir}/package"

#删除软件包
DELETE_PACKAGE() {
    local PKG_NAME=$1
    rm -rf $(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    echo "【LinInfo】删除插件：$PKG_NAME"
}

# 删除并备份插件(包名是文件夹名)
DELETE_AND_BACKUP_PACKAGE() {
    local PKG_NAME=$1
    path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    path_default_bak="${path_default}_bak"
    [ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
    [ -d "$path_default" ] && mv -f ${path_default} ${path_default_bak} && echo "【LinInfo】备份${PKG_NAME}：${path_default} -> ${path_default_bak}"
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
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)
    local SEARCH_TYPE_SURE=$5

    searchType="*$PKG_NAME*"
    if [[ $SEARCH_TYPE_SURE == "1" ]]; then
        searchType="$PKG_NAME"
    fi

    # 删除原本同名的软件包
    the_exist_pkg=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$searchType" -prune)
    if [ -n "$the_exist_pkg" ]; then
        echo "【LinInfo】删除同名插件：$the_exist_pkg"
        rm -rf $the_exist_pkg
    fi

    # Clone插件
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"
    echo "【LinInfo】成功clone插件：$PKG_NAME"
    echo ""
    if [[ $PKG_SPECIAL == "pkg" ]]; then
        cp -rf $(find ./$REPO_NAME/*/ -maxdepth 1 -type d -iname "$searchType" -prune) ./
        rm -rf ./$REPO_NAME/
    elif [[ $PKG_SPECIAL == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
        echo "【LinInfo】重命名插件：$PKG_NAME <= $REPO_NAME"
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
        echo "【LinInfo】删除同名插件包库：$the_exist_pkg"
        rm -rf $the_exist_pkg
    fi

    # Clone插件
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" $PKG_NAME
    echo "【LinInfo】成功clone插件包库：$PKG_NAME"
    echo ""
}

REMOVE_PACKAGE_FROM_REPO() {
    local PKG_NAME=$1
        # 删除原本同名的软件包
    the_exist_pkg=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$PKG_NAME" -prune)
    if [ -n "$the_exist_pkg" ]; then
        echo "【LinInfo】删除同名插件包库：$the_exist_pkg"
        rm -rf $the_exist_pkg
    fi
}

MOVE_PACKAGE_FROM_LIST() {
    local PKG_NAME=$1
    local LIST_REPO=$2

    found=$(find ./"$LIST_REPO"/*/ -maxdepth 1 -type d -iname "$PKG_NAME" -print)
    if [ $? -eq 0 ]; then
        cp -rf $found ./
        echo "【LinInfo】复制插件包库${LIST_REPO}的${PKG_NAME}到package中"
    else
        echo "【LinInfo】未找到插件包库${LIST_REPO}的${PKG_NAME}"
    fi
}





#UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名" "是否精准搜索插件"

UPDATE_PACKAGE "luci-theme-argon" "jerrykuku/luci-theme-argon" "master"
# DELETE_PACKAGE "luci-theme-argon"
# UPDATE_PACKAGE_FROM_REPO "custom_packages_sbwml_argon" "sbwml/luci-theme-argon" "openwrt-24.10"
# MOVE_PACKAGE_FROM_LIST "luci-theme-argon" "custom_packages_sbwml_argon"
# REMOVE_PACKAGE_FROM_REPO "custom_packages_sbwml_argon"

#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"
#UPDATE_PACKAGE "luci-app-wolplus" "animegasan/luci-app-wolplus" "master"
DELETE_PACKAGE "luci-app-wolplus"
UPDATE_PACKAGE_FROM_REPO "custom_packages_sundaqiang" "sundaqiang/openwrt-packages" "master"
MOVE_PACKAGE_FROM_LIST "luci-app-wolplus" "custom_packages_sundaqiang"
REMOVE_PACKAGE_FROM_REPO "custom_packages_sundaqiang"

# # lean源码不可用：luci-theme-design
# DELETE_PACKAGE "luci-theme-design"
# UPDATE_PACKAGE_FROM_REPO "custom_packages_kenzok8" "kenzok8/openwrt-packages" "master"
# MOVE_PACKAGE_FROM_LIST "luci-theme-design" "custom_packages_kenzok8"
# REMOVE_PACKAGE_FROM_REPO "custom_packages_kenzok8"


# UPDATE_PACKAGE "luci-app-netwizard" "kiddin9/luci-app-netwizard" "master" # 测试不能用，不加
# UPDATE_PACKAGE "luci-app-netspeedtest" "muink/luci-app-netspeedtest" "master"

DELETE_PACKAGE "wrtbwmon"
DELETE_PACKAGE "luci-app-wrtbwmon"
DELETE_PACKAGE "luci-app-onliner"
#DELETE_PACKAGE "luci-app-netwizard"
# DELETE_PACKAGE "homebox"
# DELETE_PACKAGE "luci-app-netspeedtest"
# UPDATE_PACKAGE_FROM_REPO "custom_packages_haiibo" "haiibo/openwrt-packages" "master"
# MOVE_PACKAGE_FROM_LIST "wrtbwmon" "custom_packages_haiibo"
# MOVE_PACKAGE_FROM_LIST "luci-app-wrtbwmon" "custom_packages_haiibo" # 1.6.3版本，luci看不到菜单，弃用
# MOVE_PACKAGE_FROM_LIST "luci-app-onliner" "custom_packages_haiibo"
#MOVE_PACKAGE_FROM_LIST "luci-app-netwizard" "custom_packages_haiibo"  # 测试不能用，不加
# MOVE_PACKAGE_FROM_LIST "homebox" "custom_packages_haiibo"
# MOVE_PACKAGE_FROM_LIST "luci-app-netspeedtest" "custom_packages_haiibo"
# REMOVE_PACKAGE_FROM_REPO "custom_packages_haiibo"


UPDATE_PACKAGE "luci-app-onliner" "danchexiaoyang/luci-app-onliner" "main" "pkg" "1"

UPDATE_PACKAGE_FROM_REPO "custom_packages_brvphoenix_wrtbwmon" "brvphoenix/wrtbwmon" "master"
MOVE_PACKAGE_FROM_LIST "wrtbwmon" "custom_packages_brvphoenix_wrtbwmon"
REMOVE_PACKAGE_FROM_REPO "custom_packages_brvphoenix_wrtbwmon"

UPDATE_PACKAGE_FROM_REPO "custom_packages_brvphoenix_app_wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"
MOVE_PACKAGE_FROM_LIST "luci-app-wrtbwmon" "custom_packages_brvphoenix_app_wrtbwmon"
REMOVE_PACKAGE_FROM_REPO "custom_packages_brvphoenix_app_wrtbwmon"


UPDATE_PACKAGE "luci-app-wechatpush" "tty228/luci-app-wechatpush" "master"
# luci-app-wechatpush依赖wrtbwmon
UPDATE_PACKAGE "luci-app-wechatpush" "tty228/luci-app-wechatpush" "master"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"



package_name="frp"
path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "${package_name}" -prune)
path_default_bak="${path_default}_bak"
[ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
[ -d "$path_default" ] && mv -f ${path_default} ${path_default_bak} && echo "【LinInfo】备份frp：${path_default} -> ${path_default_bak}"
git clone --depth=1 --single-branch -b main https://github.com/user1121114685/frp.git ${path_default}
if [ -d ${path_default} ]; then
     echo "【LinInfo】替换${package_name}成功：${path_default}"
     [ -d "$path_default_bak" ] && rm -fr "$path_default_bak"
else
    mv -f "${path_default_bak}" "${path_default}"
    echo "【LinInfo】替换${package_name}失败，还原${package_name}"
fi

DELETE_PACKAGE "luci-app-frpc"
DELETE_PACKAGE "luci-app-frps"
UPDATE_PACKAGE_FROM_REPO "custom_packages_superzjg_frp" "superzjg/luci-app-frpc_frps" "main"
MOVE_PACKAGE_FROM_LIST "luci-app-frpc" "custom_packages_superzjg_frp"
MOVE_PACKAGE_FROM_LIST "luci-app-frps" "custom_packages_superzjg_frp"
REMOVE_PACKAGE_FROM_REPO "custom_packages_superzjg_frp"

version_workdir="${openwrt_workdir}"

# 修复lang_node编译问题
config_version=$(grep CONFIG_VERSION_NUMBER "${version_workdir}/.config" | cut -d '=' -f 2 | tr -d '"' | awk '{print $2}')
include_version=$(grep -oP '^VERSION_NUMBER:=.*,\s*\K[0-9]+\.[0-9]+\.[0-9]+(-*)?' "${version_workdir}/include/version.mk" | tail -n 1 | sed -E 's/([0-9]+\.[0-9]+)\..*/\1/')
package_version=$(grep 'openwrt-' "${version_workdir}/feeds.conf.default" | grep -oP 'openwrt-\K[^;]*')
op_version="${config_version:-${include_version:-${package_version}}}"
echo "【LinInfo】openwrt版本号：${op_version}；config_version：${config_version:-无}；include_version：${include_version:-无}；package_version：${package_version:-无}"
if [ -n "$op_version" ]; then  
    path_node_makefile="${version_workdir}/feeds/packages/lang/node"
    path_node_dir_bak="${version_workdir}/feeds/packages/lang/bak_node"
    [ -d "$path_node_dir_bak" ] && rm -fr "$path_node_dir_bak"
    [ -d "$path_node_makefile" ] && mv -f "$path_node_makefile" "$path_node_dir_bak" && echo "【LinInfo】备份lang_node：${path_node_makefile} -> ${path_node_dir_bak}"

    git clone -b "packages-$op_version" https://github.com/sbwml/feeds_packages_lang_node-prebuilt "$path_node_makefile"

    if [ -d "$path_node_makefile" ]; then
        echo "【LinInfo】替换lang_node for openwrt_${op_version}成功：${path_node_makefile}"
        [ -d "$path_node_dir_bak" ] && rm -fr "$path_node_dir_bak"
    else
        mv -f "$path_node_dir_bak" "$path_node_makefile"
        echo "【LinInfo】替换lang_node for openwrt_${op_version}失败，还原lang_node"
    fi
else
    echo "【LinInfo】openwrt版本号未知"
fi

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



#更新软件包版本
UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-not}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

    echo " "

    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi

    echo "$PKG_NAME version update has started!"

    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Pho 'PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)' $PKG_FILE | head -n 1)
        local PKG_VER=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease|$PKG_MARK)) | first | .tag_name")
        local NEW_VER=$(echo $PKG_VER | sed "s/.*v//g; s/_/./g")
        local NEW_HASH=$(curl -sL "https://codeload.github.com/$PKG_REPO/tar.gz/$PKG_VER" | sha256sum | cut -b -64)
        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")

        echo "$OLD_VER $PKG_VER $NEW_VER $NEW_HASH"

        if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE $NEW_VER version has been updated!"
        else
            echo "$PKG_FILE $NEW_VER version is already the latest!"
        fi
    done
}

# UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
# UPDATE_VERSION "sing-box"
# UPDATE_VERSION "tailscale"
UPDATE_VERSION "alist"
#修复Openvpnserver一键生成证书
UPDATE_VERSION "openvpn-easy-rsa" 


# 预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
    HP_RULES="surge"
    HP_PATCH="./homeproxy/root/etc/homeproxy"

    chmod +x ./$HP_PATCH/scripts/*
    rm -rf ./$HP_PATCH/resources/*

    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULES/
    cd ./$HP_RULES/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

    echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
    sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
    mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATCH/resources/

    cd .. && rm -rf ./$HP_RULES/

    echo "【LinInfo】homeproxy date has been updated!"
fi

# 移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
    sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

    echo "【LinInfo】passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
    sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
    sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
    sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

    echo "s【LinInfo】sr-plus has been fixed!"
fi

# 修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
    sed -i '/\/files/d' $TS_FILE
    echo "【LinInfo】tailscale has been fixed!"
fi

#预置OpenClash内核和数据
# if [ -d *"openclash"* ]; then
#     CORE_VER="https://raw.githubusercontent.com/vernesong/OpenClash/core/dev/core_version"
#     # CORE_TYPE=$(echo $WRT_TARGET | grep -Eiq "64|86" && echo "amd64" || echo "arm64")
#     CORE_TYPE="arm64"
#     CORE_TUN_VER=$(curl -sL $CORE_VER | sed -n "2{s/\r$//;p;q}")

#     CORE_DEV="https://github.com/vernesong/OpenClash/raw/core/dev/dev/clash-linux-$CORE_TYPE.tar.gz"
#     CORE_MATE="https://github.com/vernesong/OpenClash/raw/core/dev/meta/clash-linux-$CORE_TYPE.tar.gz"
#     CORE_TUN="https://github.com/vernesong/OpenClash/raw/core/dev/premium/clash-linux-$CORE_TYPE-$CORE_TUN_VER.gz"

#     GEO_MMDB="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"
#     GEO_SITE="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geosite.dat"
#     GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"

#     cd ./luci-app-openclash/root/etc/openclash/

#     curl -sL -o Country.mmdb $GEO_MMDB && echo "Country.mmdb done!"
#     curl -sL -o GeoSite.dat $GEO_SITE && echo "GeoSite.dat done!"
#     curl -sL -o GeoIP.dat $GEO_IP && echo "GeoIP.dat done!"

#     mkdir ./core/ && cd ./core/

#     curl -sL -o meta.tar.gz $CORE_MATE && tar -zxf meta.tar.gz && mv -f clash clash_meta && echo "meta done!"
#     curl -sL -o tun.gz $CORE_TUN && gzip -d tun.gz && mv -f tun clash_tun && echo "tun done!"
#     curl -sL -o dev.tar.gz $CORE_DEV && tar -zxf dev.tar.gz && echo "dev done!"

#     chmod +x ./* && rm -rf ./*.gz

#     echo "【LinInfo】openclash date has been updated!"
# fi



