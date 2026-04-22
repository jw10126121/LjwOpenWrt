#!/bin/bash

# 说明：验证 diy_config.sh 在当前目录不是 openwrt 时，
# 会优先使用 OPENWRT_PATH，再回退到 ./openwrt。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

grep -Fq 'if [ -n "${OPENWRT_PATH:-}" ] && [ -d "${OPENWRT_PATH}" ]; then' "$TARGET_SCRIPT"
grep -Fq 'cd "${OPENWRT_PATH}"' "$TARGET_SCRIPT"
grep -Fq 'elif [ -d "./openwrt" ]; then' "$TARGET_SCRIPT"

echo "test_diy_config_openwrt_path_fallback: ok"
