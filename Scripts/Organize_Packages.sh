#!/bin/bash

### --- 取参 --- ###

ACTION_DIR=$1

[ -z "$ACTION_DIR" ] && echo "【Lin】错误：未指定操作目录" && exit 1;

### --- 方法 --- ###

# 整理依赖包列表
UPDATE_PACKAGE_LIST() {

	local ACTION_DIR=$1
	local PACKAGE_PRE_LIST=$2
	PACKAGE_NAME=$3

	# 如果没有输入包名，就取luci-app-或者luci-theme开头的内容作为包名
	if [ -z "${PACKAGE_NAME}" ]; then
		PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | grep -o 'luci-(app|theme)-[[:alnum:]-]*_\?' | sed 's/_$//' | head -n1)	
		# PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | tr ' ' '\n' | grep -E '^luci-(app|theme)-' | sed 's/_$//' | head -n1)
		# 如果没有包名，就取第一个作为包名
		if [ -z "${PACKAGE_NAME}" ]; then
			PACKAGE_NAME=$(echo "$PACKAGE_PRE_LIST" | awk '{print $1}' | sed 's/_$//')
		fi
	fi

	echo "【Lin】操作目录：${ACTION_DIR}，整理${PACKAGE_NAME}的安装包"

	PACKAGE_DIRNAME="$ACTION_DIR/$PACKAGE_NAME"
	mkdir -p "$PACKAGE_DIRNAME"
	for pkg in $PACKAGE_PRE_LIST; do
	    for ext in ipk apk; do
	    	find "$ACTION_DIR" -name "${pkg}*.${ext}" 2>/dev/null -exec cp -r {} "$PACKAGE_DIRNAME" \;
	    done
	done

}

# 删除依赖包列表
DELETE_PACKAGE_LIST() {

 	local ACTION_DIR=$1
	local PACKAGE_PRE_LIST=$2

	for pkg in $PACKAGE_PRE_LIST; do
	    for ext in ipk apk; do
	    	find "$ACTION_DIR" -maxdepth 1 -name "${pkg}*.$ext" 2>/dev/null -exec rm -rf {} \;
	    done
	done

}

### --- 执行 --- ###

### --- 包列表定义 --- ###
declare -A PACKAGES=(
    ["openclash"]="luci-app-openclash_ kmod-inet-diag_ coreutils-nohup_ libcap-bin_ libgmp10_ libruby3.1_ libyaml_ ruby_ ruby-bigdecimal_ ruby-date_ ruby-digest_ ruby-enc_ ruby-forwardable_ ruby-pstore_ ruby-psych_ ruby-stringio_ ruby-strscan_ ruby-yaml_ unzip_"
    ["ssrplus"]="luci-app-ssr-plus_ luci-i18n-ssr-plus-zh-cn_ resolveip_ lua-neturl_ libev_ libpcre2_ libsodium_ dns2socks_ dns2tcp_ mosdns_ microsocks_ shadowsocks-rust-sslocal_ shadowsocks-rust-ssserver_ shadowsocksr-libev-ssr-check_ shadowsocksr-libev-ssr-local_ shadowsocksr-libev-ssr-redir_ simple-obfs-client_ tcping_ xray-core_ coreutils_ coreutils-base64_"
    ["sqm"]="luci-app-sqm_ luci-i18n-sqm-zh-cn_ sqm-scripts_ kmod-ipt-ipopt_ kmod-ifb_ kmod-sched-cake_ kmod-sched-core_ iptables-mod-ipopt_ tc-tiny_ sqm-scripts-nss_ kmod-qca-nss-drv-igs_ kmod-qca-nss-drv-qdisc_"
    ["openvpnserver"]="luci-app-openvpn-server_ luci-i18n-openvpn-server-zh-cn_ liblzo_ openvpn-easy-rsa_ openvpn-openssl_"
    ["samba4"]="luci-app-samba4_ luci-i18n-samba4-zh-cn_ libattr_ libgnutls_ libavahi-client_ libavahi-dbus-support_ libdaemon_ libdbus_ libexpat_ libgmp_ libnettle_ libtasn1_ libtirpc_ liburing_ avahi-dbus-daemon_ wsdd2_ samba4-libs_ samba4-server_ attr_ dbus_"
    ["mwan3"]="luci-app-mwan3_ luci-i18n-mwan3-zh-cn_ pdnsd-alt_ mwan3_"
    ["alist"]="luci-app-alist_ luci-i18n-alist-zh-cn_ alist_ libfuse_ fuse-utils_"
    ["wrtbwmon"]="luci-app-wrtbwmon_ luci-i18n-wrtbwmon-zh-cn_ wrtbwmon_"
    ["netdata"]="luci-app-netdata_ luci-i18n-netdata-zh-cn_ netdata_ coreutils-timeout_"
    ["rclone"]="luci-app-rclone_ luci-i18n-rclone-zh-cn_ rclone_ rclone-config_ rclone-ng_ rclone-webui-react_ fuse-utils_"
    ["frps"]="luci-app-frps_ frps_"
    ["frpc"]="luci-app-frpc_ frpc_"
	["filetransfer"]="luci-app-filetransfer_ luci-i18n-filetransfer-zh-cn_ luci-lib-fs_"
	["socat"]="luci-app-socat_ socat_ luci-i18n-socat-zh-cn_"
	["diskman"]="luci-app-diskman_ luci-i18n-diskman-zh-cn_ libparted_ parted_ smartmontools_"
	["nlbwmon"]="luci-app-nlbwmon_ nlbwmon_ luci-i18n-nlbwmon-zh-cn_ kmod-nf-conntrack-netlink_"
	["wifischedule"]="luci-app-wifischedule_ wifischedule_ luci-i18n-wifischedule-zh-cn_"
	["usbprinter"]="luci-app-usb-printer_ kmod-usb-printer_ p910nd_ luci-i18n-usb-printer-zh-cn_"
	["pushbot"]="luci-app-pushbot_ iputils-arping_ jq_ curl_"
	["wechatpush"]="luci-app-wechatpush_ luci-i18n-wechatpush-zh-cn_ iputils-arping_ jq_ curl_ bash_"
	["oaf"]="luci-app-oaf_ luci-i18n-oaf-zh-cn_ appfilter_ kmod-oaf_"
	["easytier"]="luci-app-easytier_ luci-i18n-easytier-zh-cn_ easytier_ kmod-tun_"
	["bandix"]="luci-app-bandix_ bandix_ luci-i18n-bandix-zh-cn_"
	["argon"]="luci-theme-argon_ curl_ jsonfilter_"
	["wolplus"]="luci-app-wolplus_ luci-i18n-wolplus-zh-cn_ etherwake_"
	["versync"]="luci-app-verysync_ verysync_"
	["vlmcsd"]="luci-app-vlmcsd_ luci-i18n-vlmcsd-zh-cn_ vlmcsd_"

	#["homeproxy"]="luci-app-homeproxy_ luci-i18n-homeproxy-zh-cn_ firewall4_ kmod-lib-crc32c_ kmod-nf-flow_ kmod-nft-core_ kmod-nft-fib_ kmod-nft-nat_ kmod-nft-offload_ kmod-nft-tproxy_ kmod-netlink-diag_ jansson_ libnftnl_ nftables-json_ chinadns-ng_ sing-box_"
)

### --- 执行 --- ###
# 先更新所有包
for pkg_name in "${!PACKAGES[@]}"; do
    UPDATE_PACKAGE_LIST "$ACTION_DIR" "${PACKAGES[$pkg_name]}"
done

# 再删除所有包
for pkg_name in "${!PACKAGES[@]}"; do
    DELETE_PACKAGE_LIST "$ACTION_DIR" "${PACKAGES[$pkg_name]}"
done


