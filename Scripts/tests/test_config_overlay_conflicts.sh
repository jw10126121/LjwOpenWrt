#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/overlays"

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_COMMON=y
EOF

cat > "$TMPDIR/DEVICE-A.txt" <<'EOF'
CONFIG_DEVICE=device-a
EOF

cat > "$TMPDIR/overlays/APK.txt" <<'EOF'
CONFIG_PKG_FORMAT=apk
EOF

cat > "$TMPDIR/overlays/IPK.txt" <<'EOF'
CONFIG_PKG_FORMAT=ipk
EOF

OUT="$TMPDIR/merged.txt"
ERR="$TMPDIR/error.txt"

if bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "apk,ipk" \
	--output "$OUT" 2>"$ERR"; then
	echo "apk/ipk should conflict" >&2
	exit 1
fi

grep -q 'overlay apk 与 ipk 不能同时启用' "$ERR"

echo "test_config_overlay_conflicts: ok"
