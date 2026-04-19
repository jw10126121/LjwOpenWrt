#!/bin/bash
#=================================================
# Description: DIY feeds script
# Lisence: MIT
#=================================================
#
# 用途：
# 1. 启用 feeds.conf.default 中默认注释掉的 helloworld feed。
# 2. 仅在 IPQ / NSS 设备上追加 qosmio 的 NSS 相关 feeds。

set -eu

feed_config_name='feeds.conf.default'
device_name="${WRT_DEVICE:-}"
source_flavor="${WRT_SOURCE_FLAVOR:-${SOURCE_FLAVOR:-lean}}"
source_flavor_lc="$(printf '%s' "${source_flavor}" | tr '[:upper:]' '[:lower:]')"

# 默认启用 helloworld feed。
sed -i "s/#src-git helloworld/src-git helloworld/g" "$feed_config_name"

# 只有“IPQ 设备 + 支持 NSS 的源码风味”才追加 qosmio 的 NSS 相关 feeds。
# 当前 lean 风味下关闭；VIKINGYFY 的 IPQ 目标允许开启。
if [[ "${device_name}" == *"IPQ"* ]] && [[ "${source_flavor_lc}" == "vikingyfy" || "${source_flavor_lc}" == nss* ]]; then
	if ! grep -q '^[^#]*qosmio/nss-packages\.git$' "$feed_config_name"; then
		echo "src-git nss_packages https://github.com/qosmio/nss-packages.git" >> "$feed_config_name"
	fi
	if ! grep -q '^[^#]*qosmio/sqm-scripts-nss\.git$' "$feed_config_name"; then
		echo "src-git sqm_scripts_nss https://github.com/qosmio/sqm-scripts-nss.git" >> "$feed_config_name"
	fi
fi
