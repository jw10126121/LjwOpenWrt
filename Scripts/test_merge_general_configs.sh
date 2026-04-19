#!/bin/bash

# 说明：验证多基础配置文件会按顺序合并，且机型配置最后覆盖前面的共享层。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MERGE_SCRIPT="$SCRIPT_DIR/merge_configs.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_ALPHA=y
CONFIG_SHARED=general
EOF

cat > "$TMPDIR/GENERAL-SERVICE.txt" <<'EOF'
CONFIG_SHARED=fw3
CONFIG_SERVICE_ONLY=y
EOF

cat > "$TMPDIR/GENERAL-FW3.txt" <<'EOF'
CONFIG_SHARED=fw3-stack
CONFIG_FW3_ONLY=y
EOF

cat > "$TMPDIR/DEVICE.txt" <<'EOF'
CONFIG_SHARED=device
CONFIG_DEVICE_ONLY=y
EOF

OUTPUT_CONFIG="$TMPDIR/output.config"

bash "$MERGE_SCRIPT" "$TMPDIR" "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" "DEVICE.txt" "$OUTPUT_CONFIG"

grep -q '^CONFIG_ALPHA=y$' "$OUTPUT_CONFIG"
grep -q '^CONFIG_SERVICE_ONLY=y$' "$OUTPUT_CONFIG"
grep -q '^CONFIG_FW3_ONLY=y$' "$OUTPUT_CONFIG"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$OUTPUT_CONFIG"
grep -n '^CONFIG_SHARED=' "$OUTPUT_CONFIG" | tail -n 1 | grep -q 'CONFIG_SHARED=device'

SINGLE_OUTPUT_CONFIG="$TMPDIR/single-output.config"
bash "$MERGE_SCRIPT" "$TMPDIR" "GENERAL.txt" "DEVICE.txt" "$SINGLE_OUTPUT_CONFIG"
grep -q '^CONFIG_ALPHA=y$' "$SINGLE_OUTPUT_CONFIG"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$SINGLE_OUTPUT_CONFIG"
if grep -q '^CONFIG_FW3_ONLY=y$' "$SINGLE_OUTPUT_CONFIG"; then
	echo "single general config should not include GENERAL-FW3 content" >&2
	exit 1
fi
if grep -q '^CONFIG_SERVICE_ONLY=y$' "$SINGLE_OUTPUT_CONFIG"; then
	echo "single general config should not include GENERAL-SERVICE content" >&2
	exit 1
fi

echo "test_merge_general_configs: ok"
