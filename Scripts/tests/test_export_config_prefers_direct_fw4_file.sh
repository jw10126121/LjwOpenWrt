#!/bin/bash

# 说明：验证 --fw fw4 时，FW4 overlay 文件的内容能正确覆盖基线配置。

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
CONFIG_GENERAL_MARKER=y
EOF

cat > "$TMPDIR/DEVICE-A.txt" <<'EOF'
CONFIG_FROM_BASE=y
CONFIG_STACK=fw3
EOF

cat > "$TMPDIR/DEVICE-A-FW4.txt" <<'EOF'
CONFIG_FROM_FW4_OVERLAY=y
CONFIG_STACK=fw4
EOF

OUT_FILE="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-A" \
    --fw "fw4" \
    --output "$OUT_FILE" >/dev/null

grep -q '^CONFIG_GENERAL_MARKER=y$' "$OUT_FILE"
grep -q '^CONFIG_FROM_BASE=y$' "$OUT_FILE"
grep -q '^CONFIG_FROM_FW4_OVERLAY=y$' "$OUT_FILE"
grep -n '^CONFIG_STACK=' "$OUT_FILE" | tail -n 1 | grep -q 'CONFIG_STACK=fw4'

echo "test_export_config_prefers_direct_fw4_file: ok"
