#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_GENERAL_SOURCE=default
EOF

cat > "$TMPDIR/GENERAL-DEVICE-SPECIAL.txt" <<'EOF'
CONFIG_GENERAL_SOURCE=special
EOF

cat > "$TMPDIR/DEVICE-SPECIAL-WIFI.txt" <<'EOF'
CONFIG_DEVICE_SPECIAL=y
EOF

cat > "$TMPDIR/DEVICE-NORMAL.txt" <<'EOF'
CONFIG_DEVICE_NORMAL=y
EOF

SPECIAL_OUT="$TMPDIR/special.txt"
NORMAL_OUT="$TMPDIR/normal.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-SPECIAL-WIFI" \
	--fw "fw3" \
	--output "$SPECIAL_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-NORMAL" \
	--fw "fw3" \
	--output "$NORMAL_OUT" >/dev/null

grep -q '^CONFIG_GENERAL_SOURCE=special$' "$SPECIAL_OUT"
grep -q '^CONFIG_DEVICE_SPECIAL=y$' "$SPECIAL_OUT"
grep -q '^CONFIG_GENERAL_SOURCE=default$' "$NORMAL_OUT"
grep -q '^CONFIG_DEVICE_NORMAL=y$' "$NORMAL_OUT"

echo "test_export_config_device_general: ok"
