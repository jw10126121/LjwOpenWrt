#!/bin/bash


ACTION_DIR=$1
# PACKAGE_NAME=$2
# PACKAGE_PRE_LIST=$3

UPDATE_PACKAGE_LIST() {

	ACTION_DIR=$1
	PACKAGE_NAME=$2
	PACKAGE_PRE_LIST=$3
	
	echo "【LinInfo】操作目录：${ACTION_DIR}，整理${PACKAGE_NAME}的安装包"
	PACKAGE_DIRNAME="$ACTION_DIR/$PACKAGE_NAME"
	mkdir -p "$PACKAGE_DIRNAME"
	for pkg in $PACKAGE_PRE_LIST; do
	    for ext in ipk apk; do
	        file=$(find "$ACTION_DIR" -name "${pkg}*.$ext" 2>/dev/null)
	        if [ -n "$file" ]; then
	            cp -r "$file" "$PACKAGE_DIRNAME"
	            echo "【LinInfo】复制文件 $file 到： $PACKAGE_DIRNAME"
	        fi
	    done
	done

}

# UPDATE_PACKAGE_LIST "$ACTION_DIR" "$PACKAGE_NAME" "$PACKAGE_PRE_LIST"

openclash_packages_pre="coreutils-nohup_ libcap-bin_ libgmp10_ libruby3.1_ libyaml_ luci-app-openclash_ ruby_ ruby-bigdecimal_ ruby-date_ ruby-digest_ ruby-enc_ ruby-forwardable_ ruby-pstore_ ruby-psych_ ruby-stringio_ ruby-strscan_ ruby-yaml_ unzip_"
ssrplus_packages_pre="resolveip_ lua-neturl_ libev_ libpcre2_ libsodium_ luci-app-ssr-plus_ luci-i18n-ssr-plus-zh-cn_ dns2socks_ dns2tcp_ mosdns_ microsocks_ shadowsocks-rust-sslocal_ shadowsocks-rust-ssserver_ shadowsocksr-libev-ssr-check_ shadowsocksr-libev-ssr-local_ shadowsocksr-libev-ssr-redir_ simple-obfs-client_ tcping_ xray-core_ coreutils_ coreutils-base64_"

UPDATE_PACKAGE_LIST "$ACTION_DIR" "package_openclash" "$openclash_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "package_ssrplus" "$ssrplus_packages_pre"