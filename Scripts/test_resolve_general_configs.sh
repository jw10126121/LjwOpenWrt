#!/bin/bash

# 说明：验证基础配置文件会按 fw 参数选择 FW3 / FW4 分层。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_general_configs.sh"

FW3_RESULT=$(bash "$RESOLVE_SCRIPT" "fw3")
[ "$FW3_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" ]

FW4_RESULT=$(bash "$RESOLVE_SCRIPT" "fw4")
[ "$FW4_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt" ]

echo "test_resolve_general_configs: ok"
