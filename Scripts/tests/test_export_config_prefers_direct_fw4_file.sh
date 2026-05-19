#!/bin/bash

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

cat > "$TMPDIR/DEVICE-A-FW3.txt" <<'EOF'
CONFIG_FROM_FW3=y
# >>> FW3-BEGIN
CONFIG_STACK=fw3
# <<< FW3-END
# >>> FW4-BEGIN
# CONFIG_STACK=fw4-from-embedded
# <<< FW4-END
EOF

cat > "$TMPDIR/DEVICE-A-FW4.txt" <<'EOF'
CONFIG_FROM_FW4_FILE=y
CONFIG_STACK=fw4-from-direct-file
EOF

OUT_FILE="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw4" \
	--output "$OUT_FILE" >/dev/null

grep -q '^CONFIG_GENERAL_MARKER=y$' "$OUT_FILE"
grep -q '^CONFIG_FROM_FW4_FILE=y$' "$OUT_FILE"
grep -q '^CONFIG_STACK=fw4-from-direct-file$' "$OUT_FILE"

if grep -q '^CONFIG_FROM_FW3=y$' "$OUT_FILE"; then
	echo "fw4 export should prefer DEVICE-A-FW4.txt over DEVICE-A-FW3.txt" >&2
	exit 1
fi

if grep -q '^CONFIG_STACK=fw4-from-embedded$' "$OUT_FILE"; then
	echo "fw4 export should not fall back to the embedded FW4 block when DEVICE-A-FW4.txt exists" >&2
	exit 1
fi

echo "test_export_config_prefers_direct_fw4_file: ok"
