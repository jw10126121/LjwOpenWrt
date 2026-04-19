#!/bin/bash

# 说明：验证 export_config.sh 能按 device/fw/overlay 参数导出完整配置。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_ALPHA=y
EOF

cat > "$TMPDIR/GENERAL-SERVICE.txt" <<'EOF'
CONFIG_SERVICE_ONLY=y
EOF

cat > "$TMPDIR/GENERAL-FW3.txt" <<'EOF'
CONFIG_STACK=fw3
EOF

cat > "$TMPDIR/GENERAL-FW4.txt" <<'EOF'
CONFIG_STACK=fw4
EOF

mkdir -p "$TMPDIR/devices" "$TMPDIR/overlays" "$TMPDIR/device-overlays"

cat > "$TMPDIR/devices/DEVICE-A.txt" <<'EOF'
CONFIG_DEVICE_ONLY=y
CONFIG_FRP_ROLE=client
EOF

cat > "$TMPDIR/device-overlays/DEVICE-A-FW4.txt" <<'EOF'
CONFIG_DEVICE_FW_ONLY=y
CONFIG_FRP_ROLE=proxy
EOF

cat > "$TMPDIR/overlays/OVERLAY.txt" <<'EOF'
CONFIG_FRP_ROLE=server
CONFIG_OVERLAY_ONLY=y
EOF

FW3_OUTPUT="$TMPDIR/fw3-merged.txt"
FW4_OUTPUT="$TMPDIR/fw4-merged.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "overlay" \
	--output "$FW3_OUTPUT"

grep -q '^CONFIG_ALPHA=y$' "$FW3_OUTPUT"
grep -q '^CONFIG_SERVICE_ONLY=y$' "$FW3_OUTPUT"
grep -q '^CONFIG_STACK=fw3$' "$FW3_OUTPUT"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$FW3_OUTPUT"
grep -q '^CONFIG_OVERLAY_ONLY=y$' "$FW3_OUTPUT"
grep -n '^CONFIG_FRP_ROLE=' "$FW3_OUTPUT" | tail -n 1 | grep -q 'CONFIG_FRP_ROLE=server'

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw4" \
	--output "$FW4_OUTPUT"

grep -q '^CONFIG_ALPHA=y$' "$FW4_OUTPUT"
grep -q '^CONFIG_SERVICE_ONLY=y$' "$FW4_OUTPUT"
grep -q '^CONFIG_STACK=fw4$' "$FW4_OUTPUT"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$FW4_OUTPUT"
grep -q '^CONFIG_DEVICE_FW_ONLY=y$' "$FW4_OUTPUT"
if grep -q '^CONFIG_OVERLAY_ONLY=y$' "$FW4_OUTPUT"; then
	echo "fw4 export should not include overlay content when overlay is omitted" >&2
	exit 1
fi
grep -n '^CONFIG_FRP_ROLE=' "$FW4_OUTPUT" | tail -n 1 | grep -q 'CONFIG_FRP_ROLE=proxy'

echo "test_export_config: ok"
