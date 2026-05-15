#!/bin/bash

# 说明：验证 diy_after_defconfig 不再预置 OpenClash Meta 内核，
# 仅保留 luci-app-openclash 包本身，由运行时按需下载。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_after_defconfig.sh"

if grep -q 'prepare_openclash_meta_core' "$TARGET_SCRIPT"; then
	echo "OpenClash core preload hook should be removed from diy_after_defconfig.sh" >&2
	exit 1
fi

if grep -q 'raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/' "$TARGET_SCRIPT"; then
	echo "OpenClash core download URL should not exist in diy_after_defconfig.sh" >&2
	exit 1
fi

echo "test_diy_after_defconfig_openclash_scope: ok"
