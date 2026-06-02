#!/bin/bash

# 说明：验证 export_config.sh 能按 device/fw/overlay 参数导出完整配置。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_ALPHA=y
CONFIG_OVERRIDE=general
CONFIG_PACKAGE_example-one=general
EOF

mkdir -p "$TMPDIR/overlays" "$TMPDIR/device-overlays"

cat > "$TMPDIR/DEVICE-A-FW3.txt" <<'EOF'
CONFIG_DEVICE_ONLY=y
CONFIG_FRP_ROLE=client
CONFIG_OVERRIDE=device
CONFIG_PACKAGE_example-one=device
# >>> SERVICE-BEGIN
CONFIG_SERVICE_ONLY=device-service
# <<< SERVICE-END
# >>> FW3-BEGIN
CONFIG_STACK=fw3
CONFIG_DEVICE_STACK=fw3-device
# <<< FW3-END
# >>> FW4-BEGIN
# CONFIG_STACK=fw4
# CONFIG_DEVICE_STACK=fw4-device
# <<< FW4-END
EOF

cat > "$TMPDIR/device-overlays/DEVICE-A-FW4.txt" <<'EOF'
CONFIG_DEVICE_FW_ONLY=y
CONFIG_FRP_ROLE=proxy
CONFIG_OVERRIDE=device-fw4
CONFIG_PACKAGE_example-one=device-fw4
EOF

cat > "$TMPDIR/overlays/OVERLAY.txt" <<'EOF'
CONFIG_FRP_ROLE=server
CONFIG_OVERLAY_ONLY=y
CONFIG_OVERRIDE=overlay
CONFIG_PACKAGE_example-one=overlay
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
test "$(grep -c '^CONFIG_ALPHA=' "$FW3_OUTPUT")" -eq 1
grep -q '^CONFIG_OVERRIDE=overlay$' "$FW3_OUTPUT"
test "$(grep -c '^CONFIG_OVERRIDE=' "$FW3_OUTPUT")" -eq 1
grep -q '^CONFIG_PACKAGE_example-one=overlay$' "$FW3_OUTPUT"
test "$(grep -c '^CONFIG_PACKAGE_example-one=' "$FW3_OUTPUT")" -eq 1
grep -q '^CONFIG_SERVICE_ONLY=device-service$' "$FW3_OUTPUT"
if grep -q '^CONFIG_GENERAL_SERVICE_LAYER=y$' "$FW3_OUTPUT"; then
	echo "fw3 export should not depend on GENERAL-SERVICE anymore" >&2
	exit 1
fi
grep -q '^CONFIG_STACK=fw3$' "$FW3_OUTPUT"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$FW3_OUTPUT"
grep -q '^CONFIG_DEVICE_STACK=fw3-device$' "$FW3_OUTPUT"
if grep -q '^CONFIG_GENERAL_FW_LAYER=y$' "$FW3_OUTPUT"; then
	echo "fw3 export should not depend on GENERAL-FW3 anymore" >&2
	exit 1
fi
grep -q '^CONFIG_OVERLAY_ONLY=y$' "$FW3_OUTPUT"
grep -n '^CONFIG_FRP_ROLE=' "$FW3_OUTPUT" | tail -n 1 | grep -q 'CONFIG_FRP_ROLE=server'

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw4" \
	--output "$FW4_OUTPUT"

grep -q '^CONFIG_ALPHA=y$' "$FW4_OUTPUT"
test "$(grep -c '^CONFIG_ALPHA=' "$FW4_OUTPUT")" -eq 1
grep -q '^CONFIG_OVERRIDE=device-fw4$' "$FW4_OUTPUT"
test "$(grep -c '^CONFIG_OVERRIDE=' "$FW4_OUTPUT")" -eq 1
grep -q '^CONFIG_PACKAGE_example-one=device-fw4$' "$FW4_OUTPUT"
test "$(grep -c '^CONFIG_PACKAGE_example-one=' "$FW4_OUTPUT")" -eq 1
grep -q '^CONFIG_SERVICE_ONLY=device-service$' "$FW4_OUTPUT"
if grep -q '^CONFIG_GENERAL_SERVICE_LAYER=y$' "$FW4_OUTPUT"; then
	echo "fw4 export should not depend on GENERAL-SERVICE anymore" >&2
	exit 1
fi
grep -q '^CONFIG_STACK=fw4$' "$FW4_OUTPUT"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$FW4_OUTPUT"
grep -q '^CONFIG_DEVICE_STACK=fw4-device$' "$FW4_OUTPUT"
if grep -q '^CONFIG_GENERAL_FW_LAYER=y$' "$FW4_OUTPUT"; then
	echo "fw4 export should not depend on GENERAL-FW4 anymore" >&2
	exit 1
fi
if grep -q '^CONFIG_DEVICE_STACK=fw3-device$' "$FW4_OUTPUT"; then
	echo "fw4 export should not keep fw3-only device stack config" >&2
	exit 1
fi
grep -q '^CONFIG_DEVICE_FW_ONLY=y$' "$FW4_OUTPUT"
if grep -q '^CONFIG_OVERLAY_ONLY=y$' "$FW4_OUTPUT"; then
	echo "fw4 export should not include overlay content when overlay is omitted" >&2
	exit 1
fi
grep -n '^CONFIG_FRP_ROLE=' "$FW4_OUTPUT" | tail -n 1 | grep -q 'CONFIG_FRP_ROLE=proxy'

echo "test_export_config: ok"
