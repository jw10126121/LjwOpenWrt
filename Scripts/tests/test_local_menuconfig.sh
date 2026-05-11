#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/local_menuconfig.sh"

test -f "$TARGET_SCRIPT"
grep -Fq 'OPENWRT_PATH=${OPENWRT_PATH:-/Volumes/OpenWrt/lede}' "$TARGET_SCRIPT"
grep -Fq 'WRT_DIY_FEEDS=${WRT_DIY_FEEDS:-diy_feeds.sh}' "$TARGET_SCRIPT"
grep -Fq 'LOCAL_SKIP_MENUCONFIG=${LOCAL_SKIP_MENUCONFIG:-false}' "$TARGET_SCRIPT"
grep -Fq 'LOCAL_CLEAN_GENERATED=${LOCAL_CLEAN_GENERATED:-true}' "$TARGET_SCRIPT"
grep -Fq "缺少 gmake。macOS 请先安装：brew install make gawk" "$TARGET_SCRIPT"
grep -Fq "缺少 gawk。macOS 请先安装：brew install make gawk" "$TARGET_SCRIPT"
grep -Fq 'git fetch --depth=1 origin "${WRT_SOURCE_HASH_INFO}"' "$TARGET_SCRIPT"
grep -Fq 'rm -rf ./staging_dir ./tmp ./logs ./package/feeds ./bin ./build_dir ./toolchain ./feeds' "$TARGET_SCRIPT"
grep -Fq 'mkdir -p ./feeds' "$TARGET_SCRIPT"
grep -Fq 'perl ./scripts/feeds update -a' "$TARGET_SCRIPT"
grep -Fq 'perl ./scripts/feeds install -a' "$TARGET_SCRIPT"
grep -Fq 'bash "$SCRIPT_ROOT/$WRT_DIY_FEEDS"' "$TARGET_SCRIPT"
grep -Fq 'bash "$SCRIPT_ROOT/export_config.sh" "${EXPORT_ARGS[@]}"' "$TARGET_SCRIPT"
grep -Fq 'make menuconfig' "$TARGET_SCRIPT"
grep -Fq 'bash ./scripts/diffconfig.sh > seed.config' "$TARGET_SCRIPT"
grep -Fq "printf '%s' \"\$WRT_FIREWALL\" | tr '[:lower:]' '[:upper:]'" "$TARGET_SCRIPT"
grep -Fq 'PATH="${LOCAL_COMPAT_DIR}:$PATH"' "$TARGET_SCRIPT"
grep -Fq 'exec gmake "$@"' "$TARGET_SCRIPT"
grep -Fq 'exec gawk "$@"' "$TARGET_SCRIPT"
grep -Fq 'exec /usr/bin/sed -i "" "$@"' "$TARGET_SCRIPT"
if grep -Fq 'WRT_FIREWALL^^' "$TARGET_SCRIPT"; then
	echo "local_menuconfig.sh should stay compatible with macOS bash 3.2" >&2
	exit 1
fi

echo "test_local_menuconfig: ok"
