#!/bin/bash

# 说明：验证 diy_after_defconfig 的 OpenClash 预置行为符合预期。
# 允许 preload_openclash_meta_core 函数存在（仅对特定设备预置内核）。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_after_defconfig.sh"

# 检查旧的函数名不应存在（曾经的 prepare_openclash_meta_core）
if grep -q 'prepare_openclash_meta_core' "$TARGET_SCRIPT"; then
    echo "Legacy prepare_openclash_meta_core should not exist" >&2
    exit 1
fi

# 检查新的预置函数应存在
if ! grep -q 'preload_openclash_meta_core' "$TARGET_SCRIPT"; then
    echo "preload_openclash_meta_core function should exist" >&2
    exit 1
fi

# 检查设备识别逻辑
if ! grep -q 'JD-AX6600-WIFI' "$TARGET_SCRIPT"; then
    echo "JD-AX6600-WIFI device check should exist" >&2
    exit 1
fi

if ! grep -q 'MT6000-WIFI' "$TARGET_SCRIPT"; then
    echo "MT6000-WIFI device check should exist" >&2
    exit 1
fi

echo "test_diy_after_defconfig_openclash_scope: ok"
