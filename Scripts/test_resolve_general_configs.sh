#!/bin/bash

# 说明：验证基础配置文件会按机型配置自动选择 FW3 / FW4 分层，且允许手工覆盖。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_general_configs.sh"

FW3_RESULT=$(bash "$RESOLVE_SCRIPT" "" "IPQ60XX-NOWIFI-FW3.txt")
[ "$FW3_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" ]

FW4_RESULT=$(bash "$RESOLVE_SCRIPT" "" "IPQ60XX-NOWIFI-FW4.txt")
[ "$FW4_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt" ]

MANUAL_RESULT=$(bash "$RESOLVE_SCRIPT" "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" "IPQ60XX-NOWIFI-FW4.txt")
[ "$MANUAL_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" ]

echo "test_resolve_general_configs: ok"
