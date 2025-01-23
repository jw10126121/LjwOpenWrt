#!/bin/bash

### --- 取参 --- ###

ACTION_DIR=$1

### --- 方法 --- ###

# 整理依赖包列表
UPDATE_PACKAGE_LIST() {

	ACTION_DIR=$1
	PACKAGE_PRE_LIST=$2
	PACKAGE_NAME=$3

	# 如果没有输入包名，就取luci-app-或者luci-theme开头的内容作为包名
	if [ -z "${PACKAGE_NAME}" ]; then
		PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | grep -o 'luci-(app|theme)-[[:alnum:]-]*_\?' | sed 's/_$//' | head -n1)	
		# PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | tr ' ' '\n' | grep -E '^luci-(app|theme)-' | sed 's/_$//' | head -n1)
	fi
	# 如果没有报名，就取第一个作为包名
	if [ -z "${PACKAGE_NAME}" ]; then
		PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | awk '{print $1}' | sed 's/_$//')
	fi

	echo "【Lin】操作目录：${ACTION_DIR}，整理${PACKAGE_NAME}的安装包"

	PACKAGE_DIRNAME="$ACTION_DIR/$PACKAGE_NAME"
	mkdir -p "$PACKAGE_DIRNAME"
	for pkg in $PACKAGE_PRE_LIST; do
	    for ext in ipk apk; do
	        file=$(find "$ACTION_DIR" -name "${pkg}*.$ext" 2>/dev/null)
	        if [ -n "$file" ]; then
	            cp -r "$file" "$PACKAGE_DIRNAME"
	            # echo "【Lin】复制文件 $file 到： $PACKAGE_DIRNAME"
	        fi
	    done
	done

}

# 删除依赖包列表
DELETE_PACKAGE_LIST() {

	ACTION_DIR=$1
	PACKAGE_PRE_LIST=$2

	for pkg in $PACKAGE_PRE_LIST; do
	    for ext in ipk apk; do
	        file=$(find "$ACTION_DIR" -name "${pkg}*.$ext" 2>/dev/null)
	        if [ -n "$file" ]; then
	        	rm -fr "$file"
	        fi
	    done
	done

}

### --- 执行 --- ###

openclash_packages_pre="luci-app-openclash_ kmod-inet-diag_ coreutils-nohup_ libcap-bin_ libgmp10_ libruby3.1_ libyaml_ ruby_ ruby-bigdecimal_ ruby-date_ ruby-digest_ ruby-enc_ ruby-forwardable_ ruby-pstore_ ruby-psych_ ruby-stringio_ ruby-strscan_ ruby-yaml_ unzip_"
ssrplus_packages_pre="luci-app-ssr-plus_ luci-i18n-ssr-plus-zh-cn_ resolveip_ lua-neturl_ libev_ libpcre2_ libsodium_ dns2socks_ dns2tcp_ mosdns_ microsocks_ shadowsocks-rust-sslocal_ shadowsocks-rust-ssserver_ shadowsocksr-libev-ssr-check_ shadowsocksr-libev-ssr-local_ shadowsocksr-libev-ssr-redir_ simple-obfs-client_ tcping_ xray-core_ coreutils_ coreutils-base64_"
sqm_packages_pre="luci-app-sqm_ luci-i18n-sqm-zh-cn_ sqm-scripts_ kmod-ipt-ipopt_ kmod-ifb_ kmod-sched-cake_ kmod-sched-core_ iptables-mod-ipopt_ tc-tiny_ sqm-scripts-nss_ kmod-qca-nss-drv-igs_ kmod-qca-nss-drv-qdisc_"
openvpnserver_packages_pre="luci-app-openvpn-server_ luci-i18n-openvpn-server-zh-cn_ liblzo_ openvpn-easy-rsa_ openvpn-openssl_"
samba4_packages_pre="luci-app-samba4_ luci-i18n-samba4-zh-cn_ libattr_ libgnutls_ libavahi-client_ libavahi-dbus-support_ libdaemon_ libdbus_ libexpat_ libgmp_ libnettle_ libtasn1_ libtirpc_ liburing_ avahi-dbus-daemon_ wsdd2_ samba4-libs_ samba4-server_ attr_ dbus_"
mwan3_packages_pre="luci-app-mwan3_ luci-i18n-mwan3-zh-cn_ pdnsd-alt_ mwan3_"
alist_packages_pre="luci-app-alist_ luci-i18n-alist-zh-cn_ alist_ libfuse_ fuse-utils_"
wrtbwmon_packages_pre="luci-app-wrtbwmon_ luci-i18n-wrtbwmon-zh-cn_ wrtbwmon_"
netdata_packages_pre="luci-app-netdata_ luci-i18n-netdata-zh-cn_ netdata_ coreutils-timeout_"
rclone_packages_pre="luci-app-rclone_ luci-i18n-rclone-zh-cn_ rclone_ rclone-config_ rclone-ng_ rclone-webui-react_ fuse-utils_"
frps_packages_pre="luci-app-frps_ frps_"
frpc_packages_pre="luci-app-frpc_ frpc_"
#homeproxy_packages_pre="luci-app-homeproxy_ luci-i18n-homeproxy-zh-cn_ firewall4_ kmod-lib-crc32c_ kmod-nf-flow_ kmod-nft-core_ kmod-nft-fib_ kmod-nft-nat_ kmod-nft-offload_ kmod-nft-tproxy_ kmod-netlink-diag_ jansson_ libnftnl_ nftables-json_ chinadns-ng_ sing-box_"

UPDATE_PACKAGE_LIST "$ACTION_DIR" "$openclash_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$ssrplus_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$sqm_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$openvpnserver_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$samba4_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$mwan3_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$alist_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$wrtbwmon_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$netdata_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$rclone_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$frps_packages_pre"
UPDATE_PACKAGE_LIST "$ACTION_DIR" "$frpc_packages_pre"
#UPDATE_PACKAGE_LIST "$ACTION_DIR" "$homeproxy_packages_pre"

DELETE_PACKAGE_LIST "$ACTION_DIR" "$openclash_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$ssrplus_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$sqm_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$openvpnserver_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$samba4_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$mwan3_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$alist_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$wrtbwmon_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$netdata_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$rclone_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$frps_packages_pre"
DELETE_PACKAGE_LIST "$ACTION_DIR" "$frpc_packages_pre"
# # DELETE_PACKAGE_LIST "$ACTION_DIR" "$homeproxy_packages_pre"

