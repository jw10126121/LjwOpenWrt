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
# OVERLAY_GROUP=package-manager
CONFIG_PKG_FORMAT=apk
EOF

cat > "$TMPDIR/overlays/IPK.txt" <<'EOF'
# OVERLAY_GROUP=package-manager
CONFIG_PKG_FORMAT=ipk
EOF

cat > "$TMPDIR/overlays/FRPS.txt" <<'EOF'
# OVERLAY_GROUP=frp
CONFIG_FRP_ROLE=server
EOF

cat > "$TMPDIR/overlays/FRPC.txt" <<'EOF'
# OVERLAY_GROUP=frp
CONFIG_FRP_ROLE=client
EOF

cat > "$TMPDIR/overlays/USB.txt" <<'EOF'
# OVERLAY_GROUP=usb
CONFIG_USB_PROFILE=full
EOF

cat > "$TMPDIR/overlays/NOUSB.txt" <<'EOF'
# OVERLAY_GROUP=usb
CONFIG_USB_PROFILE=none
EOF

OUT="$TMPDIR/merged.txt"
SECOND_OUT="$TMPDIR/merged-second.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "apk,frps,usb,ipk,frpc,nousb" \
	--output "$OUT"

grep -q '^CONFIG_COMMON=y$' "$OUT"
grep -q '^CONFIG_DEVICE=device-a$' "$OUT"
grep -q '^CONFIG_PKG_FORMAT=ipk$' "$OUT"
grep -q '^CONFIG_FRP_ROLE=client$' "$OUT"
grep -q '^CONFIG_USB_PROFILE=none$' "$OUT"
if grep -q '^CONFIG_PKG_FORMAT=apk$' "$OUT"; then
	echo "earlier package-manager overlay should be dropped" >&2
	exit 1
fi
if grep -q '^CONFIG_FRP_ROLE=server$' "$OUT"; then
	echo "earlier frp overlay should be dropped" >&2
	exit 1
fi
if grep -q '^CONFIG_USB_PROFILE=full$' "$OUT"; then
	echo "earlier usb overlay should be dropped" >&2
	exit 1
fi

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "ipk,apk,nousb,usb,frpc,frps" \
	--output "$SECOND_OUT"

grep -q '^CONFIG_PKG_FORMAT=apk$' "$SECOND_OUT"
grep -q '^CONFIG_FRP_ROLE=server$' "$SECOND_OUT"
grep -q '^CONFIG_USB_PROFILE=full$' "$SECOND_OUT"

echo "test_config_overlay_conflicts: ok"
