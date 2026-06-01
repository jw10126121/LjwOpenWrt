#!/bin/bash

# 说明：验证 --fw fw4 时，脚本使用 {device}.txt 作为基线，
# 并追加 {device}-FW4.txt 作为覆盖。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/device-overlays"

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_GENERAL_BASE=y
EOF

# 基线配置（模拟 FW3 完整文件）
cat > "$TMPDIR/DEVICE-X.txt" <<'EOF'
CONFIG_GENERAL_MARKER=y
CONFIG_DEVICE_BASE=y
CONFIG_FIREWALL=iptables
CONFIG_PROXY=ssrplus
CONFIG_PLUGIN_A=y
CONFIG_PLUGIN_B=m
EOF

# FW4 覆盖文件（只含差异行）
cat > "$TMPDIR/DEVICE-X-FW4.txt" <<'EOF'
# --- 防火墙栈切换 ---
CONFIG_FIREWALL=nftables

# --- 代理插件切换 ---
CONFIG_PROXY=homeproxy

# --- 插件状态切换 ---
CONFIG_PLUGIN_A=m
CONFIG_PLUGIN_B=y
EOF

# 测试 1：--fw fw3 不应包含 FW4 覆盖内容
FW3_OUT="$TMPDIR/fw3.txt"
bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-X" \
    --fw "fw3" \
    --output "$FW3_OUT" >/dev/null

grep -q '^CONFIG_GENERAL_BASE=y$' "$FW3_OUT"
grep -q '^CONFIG_GENERAL_MARKER=y$' "$FW3_OUT"
grep -q '^CONFIG_FIREWALL=iptables$' "$FW3_OUT"
grep -q '^CONFIG_PROXY=ssrplus$' "$FW3_OUT"
grep -q '^CONFIG_PLUGIN_A=y$' "$FW3_OUT"
grep -q '^CONFIG_PLUGIN_B=m$' "$FW3_OUT"

# 测试 2：--fw fw4 应包含基线 + FW4 覆盖
FW4_OUT="$TMPDIR/fw4.txt"
bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-X" \
    --fw "fw4" \
    --output "$FW4_OUT" >/dev/null

grep -q '^CONFIG_GENERAL_BASE=y$' "$FW4_OUT"
grep -q '^CONFIG_GENERAL_MARKER=y$' "$FW4_OUT"
grep -q '^CONFIG_DEVICE_BASE=y$' "$FW4_OUT"
# FW4 覆盖应生效
grep -n '^CONFIG_FIREWALL=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_FIREWALL=nftables'
grep -n '^CONFIG_PROXY=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PROXY=homeproxy'
grep -n '^CONFIG_PLUGIN_A=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PLUGIN_A=m'
grep -n '^CONFIG_PLUGIN_B=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PLUGIN_B=y'

# 测试 3：无 FW4 覆盖文件时，--fw fw4 应正常工作（只是没有覆盖）
cat > "$TMPDIR/DEVICE-Y.txt" <<'EOF'
CONFIG_ONLY_BASE=y
EOF

FW4_NO_OVERLAY="$TMPDIR/fw4-no-overlay.txt"
bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-Y" \
    --fw "fw4" \
    --output "$FW4_NO_OVERLAY" >/dev/null

grep -q '^CONFIG_GENERAL_BASE=y$' "$FW4_NO_OVERLAY"
grep -q '^CONFIG_ONLY_BASE=y$' "$FW4_NO_OVERLAY"

echo "test_export_config_fw4_overlay: ok"
